#!/system/bin/sh
#
# thermal_safety_guard.sh
#
# Purpose
# -------
# Keep CPU and GPU temperatures under configured thresholds using a two-layer approach:
#
#   1) Primary control: adjust TTJ (thermal junction thresholds) as a sliding scale.
#      - When over threshold, decrease TTJ quickly in TTJ_STEP increments.
#      - If GPU is over threshold, decrease TTJ and GPU max frequency at the same time.
#
#   2) Fallback control: if TTJ reaches TTJ_MIN and temperatures are still over threshold,
#      clamp clocks by stepping down GPU and CPU max frequencies.
#
# Recovery policy
# ---------------
# Recovery happens in this order:
#   1) Recover clocks first. TTJ is held at its current value until clocks are back at max.
#      - GPU clock step-up cadence: one step every GPU_RECOVER_STEP_SECS (default 10s),
#        including the first step-up after becoming under-threshold.
#      - CPU clock step-up cadence: one step every CPU_RECOVER_STEP_SECS (default 5s).
#
#   2) After clocks are at max, recover TTJ:
#      - Increase TTJ by TTJ_STEP every TTJ_RECOVER_STEP_SECS (default 3s) until TTJ_MAX.
#
#   3) Only after BOTH clocks and TTJ are fully recovered and remain under threshold
#      continuously for FULL_RECOVERY_HOLD_SECS (default 120s), apply the setclock profile
#      (setclock_max/stock/powersave) once.
#
# Temperature acquisition
# -----------------------
# CPU temperature:
#   - Prefer thermal zone type "soc_max" if present.
#   - Otherwise, use the maximum across all "cpu-*" zones.
# GPU temperature:
#   - Use the maximum across "gpu1" and "gpu2".
#   - If GPU temps temporarily fail to read, reuse the last valid GPU temp for
#     up to GPU_STALE_SECS seconds.
#
# TTJ write format
# ----------------
# The TTJ node expects a prefix and three values:
#   echo "TTJ 115000 115000 115000" > /sys/kernel/thermal/ttj
#
# GPU ramp-down preparation (written once per cooldown window)
# ------------------------------------------------------------
# When GPU overheating begins, these are written once, then not written again until
# GPU_RAMP_PREP_COOLDOWN_SECS has elapsed. This prevents spamming when the GPU
# oscillates around the threshold.
#   echo -1 > /proc/gpufreqv2/fix_target_opp_index
#   echo 42 > .../dvfsrc_force_vcore_dvfs_opp
#
# Tunables (optional environment variables)
# -----------------------------------------
# Thresholds (°C):
#   CPU_LIMIT_C=110
#   GPU_LIMIT_C=105
#
# TTJ sliding scale:
#   TTJ_MAX=115000
#   TTJ_MIN=50000
#   TTJ_STEP=5000
#
# Timing:
#   ADJUST_SLEEP_SECS=0.1           (fast TTJ ramp-down loop)
#   LOOP_SLEEP_SECS=1               (main loop sleep for recovery/steady state)
#   GPU_RECOVER_STEP_SECS=10        (GPU max frequency step-up cadence)
#   CPU_RECOVER_STEP_SECS=5         (CPU max frequency step-up cadence)
#   TTJ_RECOVER_STEP_SECS=3         (TTJ step-up cadence)
#   FULL_RECOVERY_HOLD_SECS=120     (must be fully recovered and under threshold this long before setclocks)
#   GPU_RAMP_PREP_COOLDOWN_SECS=30  (minimum time between ramp-prep writes)
#
# GPU stale fallback:
#   GPU_STALE_SECS=10
#

CPU_LIMIT_C="${CPU_LIMIT_C:-110}"
GPU_LIMIT_C="${GPU_LIMIT_C:-105}"

THERM_BASE="/sys/class/thermal"
TTJ_NODE="${TTJ_NODE:-/sys/kernel/thermal/ttj}"

TTJ_MAX="${TTJ_MAX:-115000}"
TTJ_MIN="${TTJ_MIN:-50000}"
TTJ_STEP="${TTJ_STEP:-5000}"

ADJUST_SLEEP_SECS="${ADJUST_SLEEP_SECS:-0.1}"
LOOP_SLEEP_SECS="${LOOP_SLEEP_SECS:-1}"

GPU_RECOVER_STEP_SECS="${GPU_RECOVER_STEP_SECS:-10}"
CPU_RECOVER_STEP_SECS="${CPU_RECOVER_STEP_SECS:-5}"
TTJ_RECOVER_STEP_SECS="${TTJ_RECOVER_STEP_SECS:-3}"

FULL_RECOVERY_HOLD_SECS="${FULL_RECOVERY_HOLD_SECS:-120}"

GPU_RAMP_PREP_COOLDOWN_SECS="${GPU_RAMP_PREP_COOLDOWN_SECS:-30}"
GPU_STALE_SECS="${GPU_STALE_SECS:-10}"

# GPU sysfs
GPU_DEVFREQ_BASE="/sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali"
GPU_AVAIL_FREQS="$GPU_DEVFREQ_BASE/available_frequencies"
GPU_GOV="$GPU_DEVFREQ_BASE/governor"
GPU_MIN_FREQ="$GPU_DEVFREQ_BASE/min_freq"
GPU_MAX_FREQ="$GPU_DEVFREQ_BASE/max_freq"
GPU_FIX_OPP="/proc/gpufreqv2/fix_target_opp_index"
DVFSRC_VCORE_OPP="/sys/devices/platform/soc/1c00f000.dvfsrc/1c00f000.dvfsrc:dvfsrc-helper/dvfsrc_force_vcore_dvfs_opp"

# CPU policies
P0="/sys/devices/system/cpu/cpufreq/policy0"
P4="/sys/devices/system/cpu/cpufreq/policy4"
P7="/sys/devices/system/cpu/cpufreq/policy7"

now_epoch() { date +%s; }

on_exit() { echo; echo "Exiting."; exit 0; }
trap on_exit INT TERM

write_sysfs() { printf '%s\n' "$2" > "$1" 2>/dev/null; }

read_first_line() {
  line=""
  IFS= read -r line < "$1" 2>/dev/null || return 1
  printf '%s\n' "$line"
  return 0
}

raw_to_c() {
  raw="$1"
  case "$raw" in
    ''|*[!0-9-]*) return 1 ;;
  esac
  [ "$raw" -gt 0 ] || return 1
  if [ "$raw" -ge 1000 ]; then
    c=$(( (raw + 500) / 1000 ))
  else
    c="$raw"
  fi
  [ "$c" -ge 1 ] || return 1
  [ "$c" -le 125 ] || return 1
  echo "$c"
  return 0
}

clamp_int() {
  v="$1"; lo="$2"; hi="$3"
  [ "$v" -lt "$lo" ] && { echo "$lo"; return 0; }
  [ "$v" -gt "$hi" ] && { echo "$hi"; return 0; }
  echo "$v"
  return 0
}

# -----------------------------
# Thermal zone discovery (once)
# -----------------------------
CPU_TEMP_FILES=""
GPU1_TEMP=""
GPU2_TEMP=""
SOC_MAX_TEMP=""

for z in "$THERM_BASE"/thermal_zone*; do
  [ -d "$z" ] || continue
  t=""
  IFS= read -r t < "$z/type" 2>/dev/null || continue
  case "$t" in
    cpu-*)   CPU_TEMP_FILES="$CPU_TEMP_FILES $z/temp" ;;
    gpu1)    GPU1_TEMP="$z/temp" ;;
    gpu2)    GPU2_TEMP="$z/temp" ;;
    soc_max) SOC_MAX_TEMP="$z/temp" ;;
  esac
done

max_temp_in_filelist() {
  max=""
  for f in $1; do
    raw=""
    IFS= read -r raw < "$f" 2>/dev/null || continue
    t="$(raw_to_c "$raw")" || continue
    if [ -z "$max" ] || [ "$t" -gt "$max" ]; then
      max="$t"
    fi
  done
  [ -n "$max" ] || return 1
  echo "$max"
  return 0
}

read_one_temp_file_c() {
  raw=""
  IFS= read -r raw < "$1" 2>/dev/null || return 1
  raw_to_c "$raw"
}

read_cpu_temp_c() {
  if [ -n "$SOC_MAX_TEMP" ]; then
    t="$(read_one_temp_file_c "$SOC_MAX_TEMP" 2>/dev/null)" && { echo "$t"; return 0; }
  fi
  [ -n "$CPU_TEMP_FILES" ] || return 1
  max_temp_in_filelist "$CPU_TEMP_FILES"
}

last_gpu=""
last_gpu_ts=0
read_gpu_temp_c() {
  gmax=""

  if [ -n "$GPU1_TEMP" ]; then
    t="$(read_one_temp_file_c "$GPU1_TEMP" 2>/dev/null)" && gmax="$t"
  fi
  if [ -n "$GPU2_TEMP" ]; then
    t="$(read_one_temp_file_c "$GPU2_TEMP" 2>/dev/null)" && {
      if [ -z "$gmax" ] || [ "$t" -gt "$gmax" ]; then
        gmax="$t"
      fi
    }
  fi

  if [ -n "$gmax" ]; then
    last_gpu="$gmax"
    last_gpu_ts="$(now_epoch)"
    echo "$gmax fresh"
    return 0
  fi

  if [ -n "$last_gpu" ]; then
    ts="$(now_epoch)"
    age=$((ts - last_gpu_ts))
    if [ "$age" -le "$GPU_STALE_SECS" ]; then
      echo "$last_gpu stale"
      return 0
    fi
  fi

  echo "NA na"
  return 1
}

# -----------------------------
# TTJ helpers
# -----------------------------
read_ttj_one() {
  [ -r "$TTJ_NODE" ] || return 1
  line="$(read_first_line "$TTJ_NODE")" || return 1
  nums="$(printf '%s\n' "$line" | tr -d ',' | tr -cd '0-9 \n')"
  set -- $nums
  [ -n "$1" ] || return 1
  echo "$1"
  return 0
}

write_ttj_all() {
  v="$1"
  [ -w "$TTJ_NODE" ] || return 1
  printf 'TTJ %s %s %s\n' "$v" "$v" "$v" > "$TTJ_NODE" 2>/dev/null || return 1
  return 0
}

write_ttj_all_verified() {
  v="$1"
  tries=0
  while [ "$tries" -lt 5 ]; do
    write_ttj_all "$v" || return 1
    r="$(read_ttj_one 2>/dev/null)" || r=""
    [ "$r" = "$v" ] && return 0
    tries=$((tries + 1))
    sleep 0.05
  done
  return 1
}

# -----------------------------
# Performance mode restore
# -----------------------------
restore_perf_mode() {
  mode="$(getprop persist.gammaos.performance_mode 2>/dev/null)"
  case "$mode" in
    max)       start setclock_max ;;
    stock)     start setclock_stock ;;
    powersave) start setclock_powersave ;;
    *)         return 0 ;;
  esac
  return 0
}

# -----------------------------
# GPU frequency stepping
# -----------------------------
gpu_freqs=""
gpu_freqs_loaded=0
gpu_idx_cur=0
gpu_idx_max=0
gpu_initialized=0

gpu_nodes_present() {
  [ -r "$GPU_AVAIL_FREQS" ] && [ -w "$GPU_GOV" ] && [ -w "$GPU_MIN_FREQ" ] && [ -w "$GPU_MAX_FREQ" ]
}

load_gpu_freqs() {
  gpu_freqs="$(read_first_line "$GPU_AVAIL_FREQS")" || return 1
  set -- $gpu_freqs
  [ -n "$1" ] || return 1
  c=0
  for f in $gpu_freqs; do c=$((c + 1)); done
  gpu_idx_cur=0
  gpu_idx_max=$((c - 1))
  gpu_freqs_loaded=1
  return 0
}

gpu_freq_at_idx() {
  idx="$1"
  i=0
  for f in $gpu_freqs; do
    if [ "$i" -eq "$idx" ]; then
      echo "$f"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

gpu_init_once() {
  write_sysfs "$GPU_GOV" "simple_ondemand"
  write_sysfs "$GPU_MIN_FREQ" "265000000"
  f0="$(gpu_freq_at_idx 0 2>/dev/null)" && write_sysfs "$GPU_MAX_FREQ" "$f0"
  gpu_initialized=1
  return 0
}

gpu_prepare_rampdown_session() {
  # Apply only if enough time has passed since the last application.
  now="$1"
  last="$2"

  if [ -z "$last" ] || [ "$last" -eq 0 ] || [ $((now - last)) -ge "$GPU_RAMP_PREP_COOLDOWN_SECS" ]; then
    [ -w "$GPU_FIX_OPP" ] && write_sysfs "$GPU_FIX_OPP" "-1"
    [ -w "$DVFSRC_VCORE_OPP" ] && write_sysfs "$DVFSRC_VCORE_OPP" "42"
    echo "$now"
    return 0
  fi

  echo "$last"
  return 0
}

gpu_step_down_one() {
  [ "$gpu_idx_cur" -lt "$gpu_idx_max" ] || return 1
  gpu_idx_cur=$((gpu_idx_cur + 1))
  f="$(gpu_freq_at_idx "$gpu_idx_cur")" || return 1
  write_sysfs "$GPU_MAX_FREQ" "$f"
  return 0
}

gpu_step_up_one() {
  [ "$gpu_idx_cur" -gt 0 ] || return 1
  gpu_idx_cur=$((gpu_idx_cur - 1))
  f="$(gpu_freq_at_idx "$gpu_idx_cur")" || return 1
  write_sysfs "$GPU_MAX_FREQ" "$f"
  return 0
}

gpu_is_fully_restored() { [ "$gpu_idx_cur" -eq 0 ]; }

# -----------------------------
# CPU frequency stepping
# -----------------------------
p0_freqs="" p4_freqs="" p7_freqs=""
p0_idx_cur=0 p4_idx_cur=0 p7_idx_cur=0
p0_idx_max=0 p4_idx_max=0 p7_idx_max=0
cpu_initialized=0

cpu_nodes_present() {
  [ -w "$P0/scaling_governor" ] && [ -w "$P0/scaling_min_freq" ] && [ -w "$P0/scaling_max_freq" ] && [ -r "$P0/scaling_available_frequencies" ] &&
  [ -w "$P4/scaling_governor" ] && [ -w "$P4/scaling_min_freq" ] && [ -w "$P4/scaling_max_freq" ] && [ -r "$P4/scaling_available_frequencies" ] &&
  [ -w "$P7/scaling_governor" ] && [ -w "$P7/scaling_min_freq" ] && [ -w "$P7/scaling_max_freq" ] && [ -r "$P7/scaling_available_frequencies" ]
}

load_policy_freqs() {
  pol="$1"
  avail="$pol/scaling_available_frequencies"
  [ -r "$avail" ] || return 1
  read_first_line "$avail"
}

count_list() { c=0; for x in $1; do c=$((c + 1)); done; echo "$c"; }

freq_at_idx() {
  list="$1"; idx="$2"
  i=0
  for f in $list; do
    if [ "$i" -eq "$idx" ]; then
      echo "$f"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

cpu_poke_policy() {
  pol="$1"
  [ -w "$pol/scaling_setspeed" ] || return 0
  write_sysfs "$pol/scaling_setspeed" "0"
  write_sysfs "$pol/scaling_setspeed" "-1"
  return 0
}

cpu_init_once() {
  write_sysfs "$P0/scaling_governor" "schedutil"
  write_sysfs "$P0/scaling_min_freq" "480000"
  f0="$(freq_at_idx "$p0_freqs" 0 2>/dev/null)" && write_sysfs "$P0/scaling_max_freq" "$f0"
  cpu_poke_policy "$P0"

  write_sysfs "$P4/scaling_governor" "schedutil"
  write_sysfs "$P4/scaling_min_freq" "400000"
  f0="$(freq_at_idx "$p4_freqs" 0 2>/dev/null)" && write_sysfs "$P4/scaling_max_freq" "$f0"
  cpu_poke_policy "$P4"

  write_sysfs "$P7/scaling_governor" "schedutil"
  write_sysfs "$P7/scaling_min_freq" "400000"
  f0="$(freq_at_idx "$p7_freqs" 0 2>/dev/null)" && write_sysfs "$P7/scaling_max_freq" "$f0"
  cpu_poke_policy "$P7"

  cpu_initialized=1
  return 0
}

cpu_step_down_one() {
  changed=0
  if [ "$p0_idx_cur" -lt "$p0_idx_max" ]; then
    p0_idx_cur=$((p0_idx_cur + 1))
    f="$(freq_at_idx "$p0_freqs" "$p0_idx_cur")" && write_sysfs "$P0/scaling_max_freq" "$f" && cpu_poke_policy "$P0" && changed=1
  fi
  if [ "$p4_idx_cur" -lt "$p4_idx_max" ]; then
    p4_idx_cur=$((p4_idx_cur + 1))
    f="$(freq_at_idx "$p4_freqs" "$p4_idx_cur")" && write_sysfs "$P4/scaling_max_freq" "$f" && cpu_poke_policy "$P4" && changed=1
  fi
  if [ "$p7_idx_cur" -lt "$p7_idx_max" ]; then
    p7_idx_cur=$((p7_idx_cur + 1))
    f="$(freq_at_idx "$p7_freqs" "$p7_idx_cur")" && write_sysfs "$P7/scaling_max_freq" "$f" && cpu_poke_policy "$P7" && changed=1
  fi
  [ "$changed" -eq 1 ]
}

cpu_step_up_one() {
  changed=0
  if [ "$p0_idx_cur" -gt 0 ]; then
    p0_idx_cur=$((p0_idx_cur - 1))
    f="$(freq_at_idx "$p0_freqs" "$p0_idx_cur")" && write_sysfs "$P0/scaling_max_freq" "$f" && cpu_poke_policy "$P0" && changed=1
  fi
  if [ "$p4_idx_cur" -gt 0 ]; then
    p4_idx_cur=$((p4_idx_cur - 1))
    f="$(freq_at_idx "$p4_freqs" "$p4_idx_cur")" && write_sysfs "$P4/scaling_max_freq" "$f" && cpu_poke_policy "$P4" && changed=1
  fi
  if [ "$p7_idx_cur" -gt 0 ]; then
    p7_idx_cur=$((p7_idx_cur - 1))
    f="$(freq_at_idx "$p7_freqs" "$p7_idx_cur")" && write_sysfs "$P7/scaling_max_freq" "$f" && cpu_poke_policy "$P7" && changed=1
  fi
  [ "$changed" -eq 1 ]
}

cpu_is_fully_restored() {
  [ "$p0_idx_cur" -eq 0 ] && [ "$p4_idx_cur" -eq 0 ] && [ "$p7_idx_cur" -eq 0 ]
}

# -----------------------------
# Initialization
# -----------------------------
if [ ! -e "$TTJ_NODE" ]; then
  echo "ERROR: TTJ node not found at $TTJ_NODE"
  exit 1
fi

if gpu_nodes_present; then
  load_gpu_freqs >/dev/null 2>&1
fi

p0_freqs="$(load_policy_freqs "$P0" 2>/dev/null)" || p0_freqs=""
p4_freqs="$(load_policy_freqs "$P4" 2>/dev/null)" || p4_freqs=""
p7_freqs="$(load_policy_freqs "$P7" 2>/dev/null)" || p7_freqs=""

if [ -n "$p0_freqs" ]; then p0_idx_cur=0; p0_idx_max=$(( $(count_list "$p0_freqs") - 1 )); fi
if [ -n "$p4_freqs" ]; then p4_idx_cur=0; p4_idx_max=$(( $(count_list "$p4_freqs") - 1 )); fi
if [ -n "$p7_freqs" ]; then p7_idx_cur=0; p7_idx_max=$(( $(count_list "$p7_freqs") - 1 )); fi

ttj_cur="$TTJ_MAX"
write_ttj_all_verified "$ttj_cur" >/dev/null 2>&1
r="$(read_ttj_one 2>/dev/null)" && ttj_cur="$r"
ttj_cur="$(clamp_int "$ttj_cur" "$TTJ_MIN" "$TTJ_MAX")"

# TTJ lowered tracking
ttj_lowered=0

# Scheduling timers: these enforce holds and prevent immediate step-up on first under-threshold tick.
next_gpu_up_ts=0
next_cpu_up_ts=0
next_ttj_up_ts=0

# Full recovery hold timer (2 minutes) before applying setclocks.
full_recovery_start_ts=0
setclocks_applied_after_full=0

# Fallback ramp-down pacing
last_fallback_down_ts=0

# GPU ramp-prep write rate limiting
gpu_ramp_prep_last_ts=0

# -----------------------------
# Main loop
# -----------------------------
while true; do
  cpu_temp="$(read_cpu_temp_c 2>/dev/null)" || cpu_temp=""
  set -- $(read_gpu_temp_c 2>/dev/null)
  gpu_temp="$1"
  gpu_state="$2"

  cpu_over=0
  gpu_over=0
  [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$CPU_LIMIT_C" ] && cpu_over=1
  [ "$gpu_temp" != "NA" ] && [ "$gpu_temp" -gt "$GPU_LIMIT_C" ] && gpu_over=1

  now="$(now_epoch)"
  action="stable"
  sleep_secs="$LOOP_SLEEP_SECS"

  clocks_clamped=0
  [ "$gpu_idx_cur" -gt 0 ] && clocks_clamped=1
  [ "$p0_idx_cur" -gt 0 ] && clocks_clamped=1
  [ "$p4_idx_cur" -gt 0 ] && clocks_clamped=1
  [ "$p7_idx_cur" -gt 0 ] && clocks_clamped=1

  fully_recovered=0
  [ "$clocks_clamped" -eq 0 ] && [ "$ttj_cur" -ge "$TTJ_MAX" ] && fully_recovered=1

  if [ "$cpu_over" -eq 1 ] || [ "$gpu_over" -eq 1 ]; then
    # Over threshold resets recovery scheduling and the 2-minute full recovery timer.
    next_gpu_up_ts=0
    next_cpu_up_ts=0
    next_ttj_up_ts=0

    full_recovery_start_ts=0
    setclocks_applied_after_full=0

    if [ "$ttj_cur" -lt "$TTJ_MAX" ]; then
      ttj_lowered=1
    fi

    # GPU ramp-prep: apply at most once per cooldown window while GPU is overheating.
    if [ "$gpu_over" -eq 1 ] && [ "$gpu_freqs_loaded" -eq 1 ] && gpu_nodes_present; then
      if [ "$gpu_initialized" -eq 0 ]; then
        gpu_init_once
      fi
      gpu_ramp_prep_last_ts="$(gpu_prepare_rampdown_session "$now" "$gpu_ramp_prep_last_ts")"
    fi

    if [ "$ttj_cur" -gt "$TTJ_MIN" ]; then
      ttj_next=$((ttj_cur - TTJ_STEP))
      [ "$ttj_next" -lt "$TTJ_MIN" ] && ttj_next="$TTJ_MIN"

      if [ "$ttj_next" -ne "$ttj_cur" ] && write_ttj_all_verified "$ttj_next"; then
        ttj_cur="$ttj_next"
        ttj_lowered=1
        action="ttj_down"
      else
        action="ttj_down_fail"
      fi

      if [ "$gpu_over" -eq 1 ] && [ "$gpu_freqs_loaded" -eq 1 ] && [ "$gpu_initialized" -eq 1 ]; then
        if gpu_step_down_one; then
          action="ttj_down+gpu_down"
        fi
      fi

      sleep_secs="$ADJUST_SLEEP_SECS"
    else
      # TTJ at min: fallback ramp-down, 1 step per second.
      if [ "$last_fallback_down_ts" -eq 0 ] || [ $((now - last_fallback_down_ts)) -ge 1 ]; then
        last_fallback_down_ts="$now"
        did_down=0

        if [ "$cpu_over" -eq 1 ] && [ "$cpu_initialized" -eq 0 ] && [ -n "$p0_freqs" ] && [ -n "$p4_freqs" ] && [ -n "$p7_freqs" ] && cpu_nodes_present; then
          cpu_init_once
        fi

        if [ "$gpu_over" -eq 1 ] && [ "$gpu_freqs_loaded" -eq 1 ] && [ "$gpu_initialized" -eq 1 ]; then
          gpu_step_down_one && did_down=1
        fi

        if [ "$cpu_over" -eq 1 ] && [ "$cpu_initialized" -eq 1 ]; then
          cpu_step_down_one && did_down=1
        fi

        [ "$did_down" -eq 1 ] && action="fallback_clocks_down" || action="fallback_at_min_or_unavailable"
      else
        action="fallback_wait"
      fi

      sleep_secs="$LOOP_SLEEP_SECS"
    fi
  else
    # Under threshold.
    last_fallback_down_ts=0

    if [ "$clocks_clamped" -eq 1 ]; then
      # Recover clocks first. TTJ recovery is blocked until clocks are fully restored.
      action="clocks_hold_wait"

      [ "$next_gpu_up_ts" -eq 0 ] && next_gpu_up_ts=$((now + GPU_RECOVER_STEP_SECS))
      [ "$next_cpu_up_ts" -eq 0 ] && next_cpu_up_ts=$((now + CPU_RECOVER_STEP_SECS))

      did_up=0

      if [ "$gpu_initialized" -eq 1 ] && ! gpu_is_fully_restored; then
        if [ "$now" -ge "$next_gpu_up_ts" ]; then
          if gpu_step_up_one; then
            did_up=1
            next_gpu_up_ts=$((now + GPU_RECOVER_STEP_SECS))
          fi
        fi
      fi

      if [ "$cpu_initialized" -eq 1 ] && ! cpu_is_fully_restored; then
        if [ "$now" -ge "$next_cpu_up_ts" ]; then
          if cpu_step_up_one; then
            did_up=1
            next_cpu_up_ts=$((now + CPU_RECOVER_STEP_SECS))
          fi
        fi
      fi

      [ "$did_up" -eq 1 ] && action="clocks_up_step" || action="clocks_hold_wait"

      # Once clocks are fully restored, arm TTJ recovery scheduling.
      if gpu_is_fully_restored && cpu_is_fully_restored; then
        next_gpu_up_ts=0
        next_cpu_up_ts=0
        [ "$ttj_lowered" -eq 1 ] && [ "$next_ttj_up_ts" -eq 0 ] && next_ttj_up_ts=$((now + TTJ_RECOVER_STEP_SECS))
      fi
    else
      # Clocks are not clamped.
      if [ "$ttj_lowered" -eq 1 ] && [ "$ttj_cur" -lt "$TTJ_MAX" ]; then
        # TTJ recovery (3-second cadence). No setclocks during TTJ recovery.
        [ "$next_ttj_up_ts" -eq 0 ] && next_ttj_up_ts=$((now + TTJ_RECOVER_STEP_SECS))

        if [ "$now" -ge "$next_ttj_up_ts" ]; then
          ttj_next=$((ttj_cur + TTJ_STEP))
          [ "$ttj_next" -gt "$TTJ_MAX" ] && ttj_next="$TTJ_MAX"

          if [ "$ttj_next" -ne "$ttj_cur" ] && write_ttj_all_verified "$ttj_next"; then
            ttj_cur="$ttj_next"
            action="ttj_up"
          else
            action="ttj_up_fail"
          fi

          next_ttj_up_ts=$((now + TTJ_RECOVER_STEP_SECS))
        else
          action="ttj_up_wait"
        fi
      else
        # TTJ is fully recovered.
        [ "$ttj_cur" -ge "$TTJ_MAX" ] && ttj_lowered=0
        next_ttj_up_ts=0
        action="stable"
      fi
    fi

    # Full recovery hold gate: only after fully recovered for FULL_RECOVERY_HOLD_SECS do we apply setclocks once.
    clocks_clamped=0
    [ "$gpu_idx_cur" -gt 0 ] && clocks_clamped=1
    [ "$p0_idx_cur" -gt 0 ] && clocks_clamped=1
    [ "$p4_idx_cur" -gt 0 ] && clocks_clamped=1
    [ "$p7_idx_cur" -gt 0 ] && clocks_clamped=1

    if [ "$clocks_clamped" -eq 0 ] && [ "$ttj_cur" -ge "$TTJ_MAX" ]; then
      if [ "$full_recovery_start_ts" -eq 0 ]; then
        full_recovery_start_ts="$now"
      fi
      hold_age=$((now - full_recovery_start_ts))
      if [ "$hold_age" -ge "$FULL_RECOVERY_HOLD_SECS" ] && [ "$setclocks_applied_after_full" -eq 0 ]; then
        restore_perf_mode
        setclocks_applied_after_full=1
        action="setclocks_after_full_recovery"
      fi
    else
      full_recovery_start_ts=0
      setclocks_applied_after_full=0
    fi
  fi

  cpu_out="${cpu_temp:-NA}"
  if [ "$gpu_temp" = "NA" ]; then
    gpu_out="NA"
  else
    [ "$gpu_state" = "stale" ] && gpu_out="${gpu_temp}(stale)" || gpu_out="$gpu_temp"
  fi

  gpu_max_now=""
  [ "$gpu_freqs_loaded" -eq 1 ] && gpu_max_now="$(gpu_freq_at_idx "$gpu_idx_cur" 2>/dev/null)" || gpu_max_now=""
  p0_max_now=""; p4_max_now=""; p7_max_now=""
  [ -n "$p0_freqs" ] && p0_max_now="$(freq_at_idx "$p0_freqs" "$p0_idx_cur" 2>/dev/null)"
  [ -n "$p4_freqs" ] && p4_max_now="$(freq_at_idx "$p4_freqs" "$p4_idx_cur" 2>/dev/null)"
  [ -n "$p7_freqs" ] && p7_max_now="$(freq_at_idx "$p7_freqs" "$p7_idx_cur" 2>/dev/null)"

  echo "CPU=${cpu_out}C GPU=${gpu_out}C over(cpu/gpu)=${cpu_over}/${gpu_over} TTJ=${ttj_cur} ttj_lowered=${ttj_lowered} gpu_max=${gpu_max_now:-NA} cpu_max(p0/p4/p7)=${p0_max_now:-NA}/${p4_max_now:-NA}/${p7_max_now:-NA} next_gpu_up=${next_gpu_up_ts} next_ttj_up=${next_ttj_up_ts} full_recovery_start=${full_recovery_start_ts} action=${action} sleep=${sleep_secs}"

  sleep "$sleep_secs"
done

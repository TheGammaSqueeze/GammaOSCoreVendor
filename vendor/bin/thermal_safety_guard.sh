#!/system/bin/sh
#
# thermal_safety_guard.sh
#
# Uses the same temp acquisition logic as your setfan script:
#   - CPU: prefer soc_max, else max(cpu-*)
#   - GPU: max(gpu1,gpu2) with stale fallback window
#
# Additions:
#   - Minimum clamp hold: 2 seconds per domain once triggered
#   - Adaptive sleep: 1.0s normally; 0.1s after any threshold crossing until
#     both CPU and GPU are under threshold for 5 seconds
#
# Tunables (optional env vars):
#   CPU_LIMIT_C=112 GPU_LIMIT_C=110
#   NORMAL_SLEEP_SECS=1 FAST_SLEEP_SECS=0.1
#   GPU_STALE_SECS=30
#   MIN_HOLD_SECS=2 CLEAR_UNDER_SECS=5

CPU_LIMIT_C="${CPU_LIMIT_C:-110}"
GPU_LIMIT_C="${GPU_LIMIT_C:-105}"

NORMAL_SLEEP_SECS="${NORMAL_SLEEP_SECS:-1}"
FAST_SLEEP_SECS="${FAST_SLEEP_SECS:-0.5}"

GPU_STALE_SECS="${GPU_STALE_SECS:-20}"

MIN_HOLD_SECS="${MIN_HOLD_SECS:-4}"
CLEAR_UNDER_SECS="${CLEAR_UNDER_SECS:-5}"

# Internals use deciseconds to avoid requiring sub-second timestamps.
# Assumes FAST_SLEEP_SECS=0.1 and NORMAL_SLEEP_SECS=1.
MIN_HOLD_DS=$((MIN_HOLD_SECS * 10))
CLEAR_UNDER_DS=$((CLEAR_UNDER_SECS * 10))

THERM_BASE="/sys/class/thermal"

last_gpu=""
last_gpu_ts=0

cpu_clamped=0
gpu_clamped=0
cpu_hold_left_ds=0
gpu_hold_left_ds=0

fast_mode=0
under_ds=0

now_epoch() { date +%s; }

on_exit() { echo; echo "Exiting."; exit 0; }
trap on_exit INT TERM

# Convert raw thermal temp to integer C (rounded) if sane.
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

# ---------- Cache thermal zone paths once ----------
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

# Outputs: "<temp_or_NA> <fresh|stale|na>"
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

write_sysfs() {
  printf '%s\n' "$2" > "$1" 2>/dev/null
}

apply_cpu_clamp() {
  # policy0
  write_sysfs /sys/devices/system/cpu/cpufreq/policy0/scaling_governor schedutil
  write_sysfs /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq 480000
  write_sysfs /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2200000
  write_sysfs /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed 0
  write_sysfs /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed -1

  # policy4
  write_sysfs /sys/devices/system/cpu/cpufreq/policy4/scaling_governor schedutil
  write_sysfs /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq 400000
  write_sysfs /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq 3200000
  write_sysfs /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed 0
  write_sysfs /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed -1

  # policy7
  write_sysfs /sys/devices/system/cpu/cpufreq/policy7/scaling_governor schedutil
  write_sysfs /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq 400000
  write_sysfs /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq 3350000
  write_sysfs /sys/devices/system/cpu/cpufreq/policy7/scaling_setspeed 0
  write_sysfs /sys/devices/system/cpu/cpufreq/policy7/scaling_setspeed -1
}

apply_gpu_clamp() {
  write_sysfs /sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali/governor simple_ondemand
  write_sysfs /sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali/min_freq 265000000
  write_sysfs /sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali/max_freq 1400000000
  write_sysfs /proc/gpufreqv2/fix_target_opp_index -1
  write_sysfs /sys/devices/platform/soc/1c00f000.dvfsrc/1c00f000.dvfsrc:dvfsrc-helper/dvfsrc_force_vcore_dvfs_opp -1
}

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

dec_hold() {
  # $1=current_hold_ds $2=tick_ds
  h="$1"
  d="$2"
  [ "$h" -le 0 ] && { echo 0; return 0; }
  if [ "$h" -le "$d" ]; then
    echo 0
  else
    echo $((h - d))
  fi
  return 0
}

# ---------- Main loop ----------
while true; do
  if [ "$fast_mode" -eq 1 ]; then
    sleep_secs="$FAST_SLEEP_SECS"
    tick_ds=1
  else
    sleep_secs="$NORMAL_SLEEP_SECS"
    tick_ds=10
  fi

  cpu_temp="$(read_cpu_temp_c 2>/dev/null)" || cpu_temp=""
  set -- $(read_gpu_temp_c 2>/dev/null)
  gpu_temp="$1"
  gpu_state="$2"

  cpu_over=0
  gpu_over=0
  [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$CPU_LIMIT_C" ] && cpu_over=1
  [ "$gpu_temp" != "NA" ] && [ "$gpu_temp" -gt "$GPU_LIMIT_C" ] && gpu_over=1

  # If we crossed any threshold, enter fast mode immediately and reset under counter.
  if [ "$cpu_over" -eq 1 ] || [ "$gpu_over" -eq 1 ]; then
    fast_mode=1
    under_ds=0
  fi

  # Decrement hold timers
  [ "$cpu_clamped" -eq 1 ] && cpu_hold_left_ds="$(dec_hold "$cpu_hold_left_ds" "$tick_ds")"
  [ "$gpu_clamped" -eq 1 ] && gpu_hold_left_ds="$(dec_hold "$gpu_hold_left_ds" "$tick_ds")"

  # Enter clamps (edge-triggered) and enforce minimum hold
  if [ "$cpu_over" -eq 1 ] && [ "$cpu_clamped" -eq 0 ]; then
    apply_cpu_clamp
    cpu_clamped=1
    cpu_hold_left_ds="$MIN_HOLD_DS"
  fi

  if [ "$gpu_over" -eq 1 ] && [ "$gpu_clamped" -eq 0 ]; then
    apply_gpu_clamp
    gpu_clamped=1
    gpu_hold_left_ds="$MIN_HOLD_DS"
  fi

  # Clear clamps only when under threshold AND minimum hold satisfied.
  # On clear, restore performance mode immediately, then re-assert the other clamp if it is still active.
  if [ "$cpu_clamped" -eq 1 ] && [ "$cpu_over" -eq 0 ] && [ "$cpu_hold_left_ds" -eq 0 ]; then
    cpu_clamped=0
    restore_perf_mode
    [ "$gpu_clamped" -eq 1 ] && apply_gpu_clamp
  fi

  if [ "$gpu_clamped" -eq 1 ] && [ "$gpu_over" -eq 0 ] && [ "$gpu_hold_left_ds" -eq 0 ]; then
    gpu_clamped=0
    restore_perf_mode
    [ "$cpu_clamped" -eq 1 ] && apply_cpu_clamp
  fi

  # Fast mode exit condition: both under threshold continuously for 5 seconds.
  if [ "$fast_mode" -eq 1 ]; then
    if [ "$cpu_over" -eq 0 ] && [ "$gpu_over" -eq 0 ]; then
      if [ "$under_ds" -lt "$CLEAR_UNDER_DS" ]; then
        under_ds=$((under_ds + tick_ds))
      fi
      [ "$under_ds" -ge "$CLEAR_UNDER_DS" ] && fast_mode=0
    else
      under_ds=0
    fi
  fi

  # Print every tick
  cpu_out="${cpu_temp:-NA}"
  if [ "$gpu_temp" = "NA" ]; then
    gpu_out="NA"
  else
    [ "$gpu_state" = "stale" ] && gpu_out="${gpu_temp}(stale)" || gpu_out="$gpu_temp"
  fi

  echo "CPU=${cpu_out}C GPU=${gpu_out}C cpu_over=$cpu_over gpu_over=$gpu_over cpu_clamped=$cpu_clamped gpu_clamped=$gpu_clamped hold(cpu/gpu)=${cpu_hold_left_ds}/${gpu_hold_left_ds}ds sleep=${sleep_secs}"

  sleep "$sleep_secs"
done

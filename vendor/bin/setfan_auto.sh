#!/system/bin/sh

PROP_NAME="persist.gammaos.fan_mode_auto"

# Thresholds (°C): cool if > COOL_ON, max if > MAX_ON
COOL_ON=70
MAX_ON=85

# Poll interval (seconds)
SLEEP_SECS=1

# Monitor-only: print every tick, do not setprop
MONITOR_ONLY="${MONITOR_ONLY:-0}"

# If GPU temp invalid, reuse last good value for this many seconds
GPU_STALE_SECS="${GPU_STALE_SECS:-30}"

# Throttle forcing
FORCE_MAX_ON_THROTTLE="1"
THROTTLE_ESCALATE_SECS="${THROTTLE_ESCALATE_SECS:-20}"

THERM_BASE="/sys/class/thermal"
THERM_K="/sys/kernel/thermal"

last_mode=""
last_gpu=""
last_gpu_ts=0
throttle_start_ts=0

now_epoch() { date +%s; }

on_exit() { echo; echo "Exiting."; exit 0; }
trap on_exit INT TERM

# Fast int read helper
read_int() {
  # $1=file
  v=""
  IFS= read -r v < "$1" 2>/dev/null || return 1
  case "$v" in
    -[0-9]*|[0-9]*) echo "$v"; return 0 ;;
    *) return 1 ;;
  esac
}

# Convert raw thermal temp to integer °C (rounded) if sane.
# returns nonzero if invalid.
raw_to_c() {
  raw="$1"
  case "$raw" in
    ''|*[!0-9-]*) return 1 ;;
  esac

  # Filter invalid/sentinel values (MediaTek often uses <=0 or -274000)
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

# -------- Cache paths once --------
CPU_TEMP_FILES=""     # list of .../temp for cpu-* zones
GPU1_TEMP=""
GPU2_TEMP=""
SOC_MAX_TEMP=""       # .../temp for soc_max (preferred CPU proxy)

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

# Kernel throttle flags (ignore APU)
IS_CPU_LIMIT_F="$THERM_K/is_cpu_limit"
IS_GPU_LIMIT_F="$THERM_K/is_gpu_limit"

# Cache cooling_device cur_state files once (cheap reads later)
CDEV_CUR_FILES=""
CDEV_TYPES=""
for c in "$THERM_BASE"/cooling_device*; do
  [ -d "$c" ] || continue
  [ -f "$c/cur_state" ] || continue
  [ -f "$c/type" ] || continue
  # Keep list; no parsing needed each tick
  CDEV_CUR_FILES="$CDEV_CUR_FILES $c/cur_state"
  CDEV_TYPES="$CDEV_TYPES $c/type"
done

max_temp_in_filelist() {
  # $1="file file file"
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
  # $1=file
  raw=""
  IFS= read -r raw < "$1" 2>/dev/null || return 1
  raw_to_c "$raw"
}

read_cpu_temp_c() {
  # Prefer soc_max if valid (fast). Fallback to scanning cpu-*.
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

read_throttle_flags() {
  cpu_lim="$(read_int "$IS_CPU_LIMIT_F" 2>/dev/null)" || cpu_lim="?"
  gpu_lim="$(read_int "$IS_GPU_LIMIT_F" 2>/dev/null)" || gpu_lim="?"
  echo "$cpu_lim $gpu_lim"
}

count_active_cooling_cached() {
  n=0
  for f in $CDEV_CUR_FILES; do
    cs="$(read_int "$f" 2>/dev/null)" || continue
    [ "$cs" -gt 0 ] && n=$((n + 1))
  done
  echo "$n"
}

handle_screen_off() {
  if [ "$MONITOR_ONLY" = "1" ]; then
    echo "sys.screen.state=off -> would run /vendor/bin/setfan_off.sh and set $PROP_NAME=off (monitor only)"
    last_mode="off"
    return 0
  fi
  /vendor/bin/setfan_off.sh >/dev/null 2>&1
  setprop "$PROP_NAME" "off"
  last_mode="off"
  echo "sys.screen.state=off -> ran setfan_off.sh and set $PROP_NAME=off"
  return 0
}

# -------- Main loop --------
while true; do
  screen_state="$(getprop sys.screen.state 2>/dev/null)"
  if [ "$screen_state" = "off" ]; then
    handle_screen_off
    sleep "$SLEEP_SECS"
    continue
  fi

  cpu_temp="$(read_cpu_temp_c 2>/dev/null)" || cpu_temp=""
  set -- $(read_gpu_temp_c 2>/dev/null)
  gpu_temp="$1"
  gpu_state="$2"

  # Base decision from temps (original logic)
  over_cool=0
  over_max=0

  [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$COOL_ON" ] && over_cool=1
  [ "$gpu_temp" != "NA" ] && [ "$gpu_temp" -gt "$COOL_ON" ] && over_cool=1

  [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$MAX_ON" ] && over_max=1
  [ "$gpu_temp" != "NA" ] && [ "$gpu_temp" -gt "$MAX_ON" ] && over_max=1

  if [ "$over_max" -eq 1 ]; then
    desired_from_temp="max"
  elif [ "$over_cool" -eq 1 ]; then
    desired_from_temp="cool"
  else
    desired_from_temp="off"
  fi

  # Throttle signals: kernel flags + active cooling devices
  set -- $(read_throttle_flags)
  cpu_lim="$1"
  gpu_lim="$2"
  active_cdev="$(count_active_cooling_cached)"

  throttling=0
  [ "$cpu_lim" != "?" ] && [ "$cpu_lim" -ne 0 ] && throttling=1
  [ "$gpu_lim" != "?" ] && [ "$gpu_lim" -ne 0 ] && throttling=1
  [ "$active_cdev" -gt 0 ] && throttling=1

  desired="$desired_from_temp"

  if [ "$FORCE_MAX_ON_THROTTLE" = "1" ]; then
    if [ "$throttling" -eq 1 ]; then
      now="$(now_epoch)"
      [ "$throttle_start_ts" -eq 0 ] && throttle_start_ts="$now"

      if [ "$desired_from_temp" = "max" ]; then
        desired="max"
      else
        desired="cool"
        age=$((now - throttle_start_ts))
        [ "$age" -ge "$THROTTLE_ESCALATE_SECS" ] && desired="max"
      fi
    else
      throttle_start_ts=0
      desired="$desired_from_temp"
    fi
  fi

  # Outputs
  cpu_out="${cpu_temp:-NA}"
  if [ "$gpu_temp" = "NA" ]; then
    gpu_out="NA"
  else
    [ "$gpu_state" = "stale" ] && gpu_out="${gpu_temp}(stale)" || gpu_out="$gpu_temp"
  fi

  if [ "$MONITOR_ONLY" = "1" ]; then
    echo "CPU=${cpu_out}C GPU=${gpu_out}C desired=$desired (temp=$desired_from_temp) lim(cpu/gpu)=$cpu_lim/$gpu_lim cdev_active=$active_cdev"
  else
    if [ "$last_mode" != "$desired" ]; then
      setprop "$PROP_NAME" "$desired"
      echo "CPU=${cpu_out}C GPU=${gpu_out}C -> set $PROP_NAME=$desired (temp=$desired_from_temp) lim(cpu/gpu)=$cpu_lim/$gpu_lim cdev_active=$active_cdev"
      last_mode="$desired"
    fi
  fi

  sleep "$SLEEP_SECS"
done

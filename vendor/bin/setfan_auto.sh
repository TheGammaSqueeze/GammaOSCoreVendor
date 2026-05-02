#!/system/bin/sh

PROP_NAME="persist.gammaos.fan_mode_auto"

# Thresholds (C): cool if > COOL_ON, max if > MAX_ON
COOL_ON=70
MAX_ON=85

# Fan profiles for each mode (passed to fan_fake_pwm)
COOL_STRENGTH=80
COOL_DUTY=20

MAX_STRENGTH=100
MAX_DUTY=20

# Poll interval (seconds)
SLEEP_SECS=1

# Debounce time (seconds) before applying a mode change, to filter noisy transitions
DEBOUNCE_SECS=3

# Monitor-only: print every tick, do not apply changes
MONITOR_ONLY="${MONITOR_ONLY:-0}"

# If GPU temp invalid, reuse last good value for this many seconds
GPU_STALE_SECS="${GPU_STALE_SECS:-30}"

THERM_BASE="/sys/class/thermal"

last_mode=""
last_gpu=""
last_gpu_ts=0

# PID of the currently running fan_fake_pwm controller started by this script (if any)
fan_pid=""

now_epoch() { date +%s; }

on_exit() {
  echo
  echo "Exiting."
  # Best-effort stop of any running controller instance started by this script
  if [ -n "$fan_pid" ]; then
    kill "$fan_pid" >/dev/null 2>&1
    wait "$fan_pid" >/dev/null 2>&1
  fi
  exit 0
}
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

# Convert raw thermal temp to integer C (rounded) if sane.
# returns nonzero if invalid.
raw_to_c() {
  raw="$1"
  case "$raw" in
    ''|*[!0-9-]*) return 1 ;;
  esac

  # Filter invalid/sentinel values
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
CPU_TEMP_FILES=""     # list of .../temp for CPU-related zones (direct CPU only)
GPU_TEMP_FILES=""     # list of .../temp for GPU-related zones

# Qualcomm CPU identification for this device:
# Keep this intentionally strict to avoid modem/wifi/camera/video/skin/etc.
is_cpu_type() {
  t="$1"
  case "$t" in
    cpuss-*|cpu-*|apss*)
      return 0
      ;;
  esac
  return 1
}

# Qualcomm GPU identification (Adreno)
is_gpu_type() {
  t="$1"
  case "$t" in
    gpu|*gpu*|*gpuss*|*adreno*|*gfx*|*kgsl*)
      return 0
      ;;
  esac
  return 1
}

for z in "$THERM_BASE"/thermal_zone*; do
  [ -d "$z" ] || continue
  [ -f "$z/type" ] || continue
  t=""
  IFS= read -r t < "$z/type" 2>/dev/null || continue

  if is_gpu_type "$t"; then
    GPU_TEMP_FILES="$GPU_TEMP_FILES $z/temp"
    continue
  fi

  if is_cpu_type "$t"; then
    CPU_TEMP_FILES="$CPU_TEMP_FILES $z/temp"
    continue
  fi
done

# Startup visibility so you can confirm correctness quickly
if [ -n "$CPU_TEMP_FILES" ]; then
  echo "CPU zones: $CPU_TEMP_FILES"
else
  echo "CPU zones: none detected"
fi

if [ -n "$GPU_TEMP_FILES" ]; then
  echo "GPU zones: $GPU_TEMP_FILES"
else
  echo "GPU zones: none detected"
fi

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

read_cpu_temp_c() {
  [ -n "$CPU_TEMP_FILES" ] || return 1
  max_temp_in_filelist "$CPU_TEMP_FILES"
}

# Outputs: "<temp_or_NA> <fresh|stale|na>"
read_gpu_temp_c() {
  gmax=""

  if [ -n "$GPU_TEMP_FILES" ]; then
    gmax="$(max_temp_in_filelist "$GPU_TEMP_FILES" 2>/dev/null)" || gmax=""
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

# Determine desired mode from temperature readings
# Output: "off" | "cool" | "max"
compute_desired_from_temps() {
  cpu_temp="$1"
  gpu_temp="$2"

  over_cool=0
  over_max=0

  [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$COOL_ON" ] && over_cool=1
  [ "$gpu_temp" != "NA" ] && [ "$gpu_temp" -gt "$COOL_ON" ] && over_cool=1

  [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$MAX_ON" ] && over_max=1
  [ "$gpu_temp" != "NA" ] && [ "$gpu_temp" -gt "$MAX_ON" ] && over_max=1

  if [ "$over_max" -eq 1 ]; then
    echo "max"
  elif [ "$over_cool" -eq 1 ]; then
    echo "cool"
  else
    echo "off"
  fi
}

# Map a mode to the strength used by that mode (for ramp start values)
mode_strength() {
  case "$1" in
    max)  echo "$MAX_STRENGTH" ;;
    cool) echo "$COOL_STRENGTH" ;;
    *)    echo "0" ;;
  esac
}

# Start the fan controller for a given mode.
# When switching between cool and max, a start_strength is supplied to produce a gradual ramp.
start_mode() {
  mode="$1"

  # Stop any existing controller instance started by this script
  if [ -n "$fan_pid" ]; then
    kill "$fan_pid" >/dev/null 2>&1
    wait "$fan_pid" >/dev/null 2>&1
    fan_pid=""
  fi

  if [ "$mode" = "off" ]; then
    /vendor/bin/setfan_off.sh >/dev/null 2>&1
    return 0
  fi

  if [ "$mode" = "cool" ]; then
    target_strength="$COOL_STRENGTH"
    duty="$COOL_DUTY"
  else
    target_strength="$MAX_STRENGTH"
    duty="$MAX_DUTY"
  fi

  # Only provide a start_strength when transitioning between cool and max.
  start_strength=""
  if [ "$last_mode" = "cool" ] && [ "$mode" = "max" ]; then
    start_strength="$(mode_strength cool)"
  elif [ "$last_mode" = "max" ] && [ "$mode" = "cool" ]; then
    start_strength="$(mode_strength max)"
  fi

  # Prefer real-time scheduling if available, otherwise use best-effort nice.
  if command -v chrt >/dev/null 2>&1; then
    if [ -n "$start_strength" ]; then
      chrt -f 80 /vendor/bin/fan_fake_pwm "$target_strength" "$duty" "$start_strength" >/dev/null 2>&1 &
    else
      chrt -f 80 /vendor/bin/fan_fake_pwm "$target_strength" "$duty" >/dev/null 2>&1 &
    fi
  else
    if [ -n "$start_strength" ]; then
      nice -n -20 /vendor/bin/fan_fake_pwm "$target_strength" "$duty" "$start_strength" >/dev/null 2>&1 &
    else
      nice -n -20 /vendor/bin/fan_fake_pwm "$target_strength" "$duty" >/dev/null 2>&1 &
    fi
  fi

  fan_pid=$!
  return 0
}

handle_screen_off() {
  if [ "$MONITOR_ONLY" = "1" ]; then
    echo "sys.screen.state=off -> would switch to off (monitor only)"
    last_mode="off"
    return 0
  fi

  start_mode "off"
  setprop "$PROP_NAME" "off"
  last_mode="off"
  echo "sys.screen.state=off -> switched to off and set $PROP_NAME=off"
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

  desired_from_temp="$(compute_desired_from_temps "$cpu_temp" "$gpu_temp")"
  desired="$desired_from_temp"

  # Outputs
  cpu_out="${cpu_temp:-NA}"
  if [ "$gpu_temp" = "NA" ]; then
    gpu_out="NA"
  else
    [ "$gpu_state" = "stale" ] && gpu_out="${gpu_temp}(stale)" || gpu_out="$gpu_temp"
  fi

  if [ "$MONITOR_ONLY" = "1" ]; then
    echo "CPU=${cpu_out}C GPU=${gpu_out}C desired=$desired (temp=$desired_from_temp)"
  else
    # Debounce any mode change to filter noisy boundary conditions.
    if [ "$last_mode" != "$desired" ]; then
      candidate="$desired"

      echo "CPU=${cpu_out}C GPU=${gpu_out}C -> candidate=$candidate, debouncing ${DEBOUNCE_SECS}s"
      sleep "$DEBOUNCE_SECS"

      # Re-read temps after debounce window and recompute desired
      cpu_temp2="$(read_cpu_temp_c 2>/dev/null)" || cpu_temp2=""
      set -- $(read_gpu_temp_c 2>/dev/null)
      gpu_temp2="$1"

      confirm="$(compute_desired_from_temps "$cpu_temp2" "$gpu_temp2")"

      if [ "$confirm" = "$candidate" ] && [ "$last_mode" != "$candidate" ]; then
        # Apply change only if it remains stable
        start_mode "$candidate"
        setprop "$PROP_NAME" "$candidate"
        echo "CPU=${cpu_out}C GPU=${gpu_out}C -> switched to $candidate and set $PROP_NAME=$candidate"
        last_mode="$candidate"
      else
        echo "CPU=${cpu_out}C GPU=${gpu_out}C -> change rejected (candidate=$candidate confirm=$confirm)"
      fi
    fi
  fi

  sleep "$SLEEP_SECS"
done

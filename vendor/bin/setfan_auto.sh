#!/system/bin/sh

PROP_NAME="persist.gammaos.fan_mode_auto"

# Thresholds (?C): cool if > COOL_ON, max if > MAX_ON
COOL_ON=60
MAX_ON=75

# Target polling interval (seconds)
SLEEP_SECS=1

# Set to 1 to only monitor (no setprop changes)
MONITOR_ONLY="${MONITOR_ONLY:-0}"

# If GPU temp is temporarily invalid, reuse last good value for this many seconds
GPU_STALE_SECS="${GPU_STALE_SECS:-30}"

THERM_BASE="/sys/class/thermal"
last_mode=""

last_gpu=""
last_gpu_ts=0

now_epoch() { date +%s; }

trim_ws() {
  echo "$1" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# Reads raw zone temp, returns integer ?C if valid, else nothing.
read_zone_temp_c() {
  zone="$1"
  raw="$(cat "$zone/temp" 2>/dev/null | tr -d '\r' | tr -d '\n')"
  [ -n "$raw" ] || return 1

  case "$raw" in
    -[0-9]*|[0-9]* ) ;;
    * ) return 1 ;;
  esac

  # Filter invalid/sentinel values (MediaTek often uses negatives)
  [ "$raw" -le 0 ] && return 1

  # milli ?C -> ?C
  if [ "$raw" -ge 1000 ]; then
    temp_c=$(( (raw + 500) / 1000 ))
  else
    temp_c="$raw"
  fi

  [ "$temp_c" -ge 1 ] || return 1
  [ "$temp_c" -le 125 ] || return 1

  echo "$temp_c"
  return 0
}

# Build zone lists once to avoid scanning 60 zones every second.
CPU_ZONES=""
GPU1_ZONE=""
GPU2_ZONE=""

for z in "$THERM_BASE"/thermal_zone*; do
  [ -d "$z" ] || continue
  type="$(trim_ws "$(cat "$z/type" 2>/dev/null)")"
  case "$type" in
    cpu-*) CPU_ZONES="${CPU_ZONES} $z" ;;
    gpu1)  GPU1_ZONE="$z" ;;
    gpu2)  GPU2_ZONE="$z" ;;
  esac
done

max_temp_in_zonelist() {
  max=""
  for z in $1; do
    t="$(read_zone_temp_c "$z")" || continue
    if [ -z "$max" ] || [ "$t" -gt "$max" ]; then
      max="$t"
    fi
  done
  [ -n "$max" ] || return 1
  echo "$max"
}

# Outputs two fields: "<temp_or_NA> <fresh|stale|na>"
read_gpu_temp_c() {
  g1=""
  g2=""
  gmax=""

  [ -n "$GPU1_ZONE" ] && g1="$(read_zone_temp_c "$GPU1_ZONE" 2>/dev/null)" || true
  [ -n "$GPU2_ZONE" ] && g2="$(read_zone_temp_c "$GPU2_ZONE" 2>/dev/null)" || true

  if [ -n "$g1" ]; then gmax="$g1"; fi
  if [ -n "$g2" ]; then
    if [ -z "$gmax" ] || [ "$g2" -gt "$gmax" ]; then
      gmax="$g2"
    fi
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

# Sleep helper to keep true 1s cadence without adding load
sleep_to_next_tick() {
  # Prefer precise sleep if toybox/busybox supports fractional sleep
  # If not, it will still sleep 1s and remain lightweight.
  sleep "$SLEEP_SECS"
}

while true; do
  cpu_temp=""
  if [ -n "$CPU_ZONES" ]; then
    cpu_temp="$(max_temp_in_zonelist "$CPU_ZONES" 2>/dev/null)" || cpu_temp=""
  fi

  gpu_read="$(read_gpu_temp_c 2>/dev/null)"
  gpu_temp="$(echo "$gpu_read" | awk '{print $1}')"
  gpu_state="$(echo "$gpu_read" | awk '{print $2}')"

  # Decide based on either CPU or GPU exceeding thresholds
  over_cool=0
  over_max=0

  if [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$COOL_ON" ]; then over_cool=1; fi
  if [ "$gpu_temp" != "NA" ] && [ "$gpu_temp" -gt "$COOL_ON" ]; then over_cool=1; fi

  if [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$MAX_ON" ]; then over_max=1; fi
  if [ "$gpu_temp" != "NA" ] && [ "$gpu_temp" -gt "$MAX_ON" ]; then over_max=1; fi

  if [ "$over_max" -eq 1 ]; then
    desired="max"
  elif [ "$over_cool" -eq 1 ]; then
    desired="cool"
  else
    desired="off"
  fi

  # Drive is the hottest observed input (useful for logging)
  drive_temp=""
  if [ -n "$cpu_temp" ]; then drive_temp="$cpu_temp"; fi
  if [ "$gpu_temp" != "NA" ]; then
    if [ -z "$drive_temp" ] || [ "$gpu_temp" -gt "$drive_temp" ]; then
      drive_temp="$gpu_temp"
    fi
  fi

  cpu_out="${cpu_temp:-NA}"
  if [ "$gpu_temp" = "NA" ]; then
    gpu_out="NA"
  else
    if [ "$gpu_state" = "stale" ]; then
      gpu_out="${gpu_temp}(stale)"
    else
      gpu_out="${gpu_temp}"
    fi
  fi
  drive_out="${drive_temp:-NA}"

  if [ "$MONITOR_ONLY" = "1" ]; then
    echo "[$(date)] CPU=${cpu_out}C GPU=${gpu_out}C Drive=${drive_out}C Desired=$desired (monitor only)"
  else
    if [ "$last_mode" != "$desired" ]; then
      setprop "$PROP_NAME" "$desired"
      echo "[$(date)] CPU=${cpu_out}C GPU=${gpu_out}C Drive=${drive_out}C -> set $PROP_NAME=$desired"
      last_mode="$desired"
    fi
  fi

  sleep_to_next_tick
done
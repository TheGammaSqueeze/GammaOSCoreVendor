#!/system/bin/sh

PROP_NAME="persist.gammaos.fan_mode_auto"
last_mode=""
INTERVAL=5

# thresholds (millidegrees °C)
CPU_COOL=50000
CPU_MAX=60000
GPU_COOL=45000
GPU_MAX=55000

# return the max raw temp (m°C) among zones whose type matches $1
get_max_temp() {
  pattern="$1"
  max=0
  for type_path in /sys/class/thermal/thermal_zone*/type; do
    if grep -qi "$pattern" "$type_path"; then
      zone=$(dirname "$type_path")
      raw=$(cat "$zone/temp" 2>/dev/null || echo 0)
      [ "$raw" -gt "$max" ] && max=$raw
    fi
  done
  echo "$max"
}

while true; do
  # get max temps
  cpu_raw=$(get_max_temp "^cpu")
  gpu_raw=$(get_max_temp "^gpu")

  # decide CPU mode
  if [ "$cpu_raw" -gt "$CPU_MAX" ]; then
    cpu_mode="max"
  elif [ "$cpu_raw" -gt "$CPU_COOL" ]; then
    cpu_mode="cool"
  else
    cpu_mode="off"
  fi

  # decide GPU mode
  if [ "$gpu_raw" -gt "$GPU_MAX" ]; then
    gpu_mode="max"
  elif [ "$gpu_raw" -gt "$GPU_COOL" ]; then
    gpu_mode="cool"
  else
    gpu_mode="off"
  fi

  # combine modes: max > cool > off
  if [ "$cpu_mode" = "max" ] || [ "$gpu_mode" = "max" ]; then
    desired="max"
  elif [ "$cpu_mode" = "cool" ] || [ "$gpu_mode" = "cool" ]; then
    desired="cool"
  else
    desired="off"
  fi

  # apply if changed
  if [ "$desired" != "$last_mode" ]; then
    setprop "$PROP_NAME" "$desired"
    # convert for logging
    cpu_c=$(awk "BEGIN{printf \"%.1f\", $cpu_raw/1000}")
    gpu_c=$(awk "BEGIN{printf \"%.1f\", $gpu_raw/1000}")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CPU_max=${cpu_c}°C GPU_max=${gpu_c}°C → set $PROP_NAME=$desired"
    last_mode="$desired"
  fi

  sleep "$INTERVAL"
done

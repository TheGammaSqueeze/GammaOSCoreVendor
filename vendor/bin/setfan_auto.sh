#!/system/bin/sh

# Fan control based on CPU (clusters) and GPU temperatures
PROP_NAME="persist.gammaos.fan_mode_auto"
last_mode=""

# Thermal zone paths
CPU_ZONE_LITTLE="/sys/class/thermal/thermal_zone22/temp"
CPU_ZONE_BIG="/sys/class/thermal/thermal_zone23/temp"
GPU_ZONE="/sys/class/thermal/thermal_zone28/temp"

while true; do
  # Read raw temperatures (milli-°C)
  cpu_l_raw=$(cat "$CPU_ZONE_LITTLE" 2>/dev/null)
  cpu_b_raw=$(cat "$CPU_ZONE_BIG" 2>/dev/null)
  gpu_raw=$(cat "$GPU_ZONE" 2>/dev/null)

  if [ -z "$cpu_l_raw" ] || [ -z "$cpu_b_raw" ] || [ -z "$gpu_raw" ]; then
    echo "[$(date)] ERROR: unable to read thermal zones" >&2
  else
    # Convert to °C
    cpu_l=$((cpu_l_raw / 1000))
    cpu_b=$((cpu_b_raw / 1000))
    gpu=$((gpu_raw / 1000))

    # Determine CPU mode:
    #   <55 → off, 55–65 → cool, >65 → max
    if [ "$cpu_l" -gt 65 ] || [ "$cpu_b" -gt 65 ]; then
      cpu_mode="max"
    elif [ "$cpu_l" -gt 55 ] || [ "$cpu_b" -gt 55 ]; then
      cpu_mode="cool"
    else
      cpu_mode="off"
    fi

    # Determine GPU mode:
    #   <39 → off, 39–45 → cool, >45 → max
    if [ "$gpu" -gt 45 ]; then
      gpu_mode="max"
    elif [ "$gpu" -gt 39 ]; then
      gpu_mode="cool"
    else
      gpu_mode="off"
    fi

    # Combine: max > cool > off
    if [ "$cpu_mode" = "max" ] || [ "$gpu_mode" = "max" ]; then
      desired="max"
    elif [ "$cpu_mode" = "cool" ] || [ "$gpu_mode" = "cool" ]; then
      desired="cool"
    else
      desired="off"
    fi

    # Apply if changed
    if [ "$last_mode" != "$desired" ]; then
      setprop "$PROP_NAME" "$desired"
      echo "[$(date)] CPU=(L=$cpu_l°C B=$cpu_b°C) GPU=$gpu°C → set $PROP_NAME=$desired"
      last_mode="$desired"
    fi
  fi

  sleep 5
done

#!/system/bin/sh

# Fan control based solely on SoC CPU temperature
PROP_NAME="persist.gammaos.fan_mode_auto"
last_mode=""
CPU_ZONE="/sys/class/thermal/thermal_zone4/temp"

while true; do
  # Read raw CPU temperature (milli-°C)
  cpu_raw=$(cat "$CPU_ZONE" 2>/dev/null)

  if [ -z "$cpu_raw" ]; then
    echo "[$(date)] ERROR: unable to read CPU thermal zone" >&2
  else
    # Convert to °C
    cpu=$(( cpu_raw / 1000 ))

    # Determine fan mode based on CPU:
    #   <55 °C → off
    #   55–65 °C → cool
    #   >65 °C → max
    if [ "$cpu" -gt 65 ]; then
      desired="max"
    elif [ "$cpu" -gt 55 ]; then
      desired="cool"
    else
      desired="off"
    fi

    # Apply if changed
    if [ "$desired" != "$last_mode" ]; then
      setprop "$PROP_NAME" "$desired"
      echo "[$(date)] CPU=${cpu}°C → set $PROP_NAME=$desired"
      last_mode="$desired"
    fi
  fi

  sleep 5
done

#!/system/bin/sh

PROP_NAME="persist.gammaos.fan_mode_auto"
last_mode=""

while true; do
  # Compute average temp (m?C  ?C)
  avg_temp=$(
    cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null \
    | awk '{ sum += $1; n++ }
           END { if (n>0) printf("%d", int((sum/n + 99)/1000)); }'
  )

  if [ -z "$avg_temp" ]; then
    echo "[$(date)] ERROR: unable to read thermal zones" >&2
  else
    # Decide desired mode based on thresholds:
    #    <45  off, 45-60  cool, >60  max
    if [ "$avg_temp" -lt 45 ]; then
      desired="off"
    elif [ "$avg_temp" -le 60 ]; then
      desired="max"
    else
      desired="max"
    fi

    # Only update if it actually changed since last loop
    if [ "$last_mode" != "$desired" ]; then
      setprop "$PROP_NAME" "$desired"
      echo "[$(date)] Temp=${avg_temp}?C  set $PROP_NAME=$desired"
      last_mode="$desired"
    fi
  fi

  sleep 5
done

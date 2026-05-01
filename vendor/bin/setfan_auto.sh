#!/system/bin/sh

PROP_NAME="persist.gammaos.fan_mode_auto"
last_mode=""

read_zone_by_type() {
  type="$1"
  for z in /sys/class/thermal/thermal_zone*; do
    if [ "$(cat "$z/type" 2>/dev/null)" = "$type" ]; then
      cat "$z/temp" 2>/dev/null
      return
    fi
  done
}

while true; do
  cpu_mC=$(read_zone_by_type mtktscpu)
  ap_mC=$(read_zone_by_type mtktsAP)

  hot_mC=""
  for v in "$cpu_mC" "$ap_mC"; do
    if [ -n "$v" ] && [ "$v" -gt -40000 ]; then
      if [ -z "$hot_mC" ] || [ "$v" -gt "$hot_mC" ]; then
        hot_mC="$v"
      fi
    fi
  done

  if [ -z "$hot_mC" ]; then
    echo "[$(date)] ERROR: unable to read mtktscpu/mtktsAP" >&2
  else
    hot_C=$(( (hot_mC + 999) / 1000 ))

    if [ "$hot_C" -lt 65 ]; then
      desired="off"
    elif [ "$hot_C" -lt 85 ]; then
      desired="cool"
    else
      desired="max"
    fi

    if [ "$last_mode" != "$desired" ]; then
      setprop "$PROP_NAME" "$desired"
      echo "[$(date)] Temp=${hot_C}C -> set $PROP_NAME=$desired"
      last_mode="$desired"
    fi
  fi

  sleep 5
done

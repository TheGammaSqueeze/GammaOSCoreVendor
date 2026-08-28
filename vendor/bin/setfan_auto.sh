#!/system/bin/sh
# Temperature-reactive fan for the RG 55G1. Runs while fan_mode=auto and
# drives persist.gammaos.fan_mode_auto (off|cool|max); init.gammaos_fan.rc
# reacts to that property and starts the matching setfan_* one-shot.
#
# Temperature is the hottest of the GPU (kgsl) and the CPU-subsystem /
# GPU-subsystem thermal zones, read by type so it survives zone renumber.
# Thresholds (deg C): below LOW = off, LOW..HIGH = cool, above HIGH = max.
# A small hysteresis avoids flapping right at a threshold.

LOW=55
HIGH=70
HYST=4

read_temp() {
  hi=0
  # kgsl GPU die temp (millidegrees)
  t=$(cat /sys/class/kgsl/kgsl-3d0/temp 2>/dev/null)
  [ -n "$t" ] && [ "$t" -gt "$hi" ] && hi=$t
  # cpuss / gpuss thermal zones (millidegrees), matched by type
  for z in /sys/class/thermal/thermal_zone*; do
    ty=$(cat "$z/type" 2>/dev/null)
    case "$ty" in
      cpuss-*|gpuss|cpu-*-*)
        t=$(cat "$z/temp" 2>/dev/null)
        [ -n "$t" ] && [ "$t" -gt "$hi" ] && hi=$t
        ;;
    esac
  done
  # millidegrees -> degrees
  echo $((hi / 1000))
}

state=""
while [ "$(getprop persist.gammaos.fan_mode)" = "auto" ]; do
  c=$(read_temp)
  case "$state" in
    max)  off_to=$((HIGH - HYST)); cool_to=$((LOW - HYST));;
    cool) off_to=$((LOW - HYST));  cool_to=$HIGH;;
    *)    off_to=$LOW;             cool_to=$HIGH;;
  esac

  if [ "$c" -ge "$HIGH" ]; then
    new=max
  elif [ "$c" -ge "$LOW" ]; then
    new=cool
  else
    new=off
  fi

  if [ "$new" != "$state" ]; then
    state=$new
    setprop persist.gammaos.fan_mode_auto "$new"
  fi
  sleep 3
done

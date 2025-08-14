#!/system/bin/sh
N="/sys/devices/platform/soc/soc:fan/hwmon/hwmon0"
PWM="$N/pwm1"
EN="$N/pwm1_enable"

chmod 666 "$PWM" "$EN" 2>/dev/null
echo 1 > "$EN" || { echo "failed to set manual mode"; exit 1; }

# Kick sequence: ON/OFF pulses to overcome stiction, then steady ON
# Adjust counts/timings if needed.
seqs='
  on 300
  off 120
  on 400
  off 120
  on 600
'
for s in $seqs; do
  case "$s" in
    on)  state=255 ;;
    off) state=0 ;;
    *)   sleep_ms="$s"; echo $state > "$PWM"; usleep $((sleep_ms*1000));;
  esac
done

# Hold ON
echo 255 > "$PWM"
# Optional: verify
printf "pwm1=%s\n" "$(cat "$PWM")"

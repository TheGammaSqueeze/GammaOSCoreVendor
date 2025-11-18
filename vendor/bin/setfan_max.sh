#!/system/bin/sh

sleep 3

N="/sys/devices/platform/soc/soc:fan/hwmon/hwmon0"
PWM="$N/pwm1"
EN="$N/pwm1_enable"

# Run fan-off logic up to 10 times with 1s delay.
# On each iteration, re-check screen/brightness and bail out to normal logic
# if the screen is on and brightness is non-zero.
fan_off_phase() {
    i=0
    while [ $i -lt 10 ]; do
        PROP_VALUE_SCREEN="$(getprop sys.screen.state)"
        PROP_VALUE_BRIGHTNESS="$(getprop debug.tracing.screen_brightness)"

        # If screen is on and brightness non-zero, stop fan-off phase
        if [ "$PROP_VALUE_SCREEN" = "on" ] && [ "$PROP_VALUE_BRIGHTNESS" != "0.0" ]; then
            return 0
        fi

        /vendor/bin/setfan_off.sh
        sleep 1
        i=$((i + 1))
    done

    # After 10 iterations, keep fan off and exit
    exit 0
}

sleep 1

# Initial check: only enter fan-off phase if screen is off or brightness is 0.0
PROP_VALUE_SCREEN="$(getprop sys.screen.state)"
PROP_VALUE_BRIGHTNESS="$(getprop debug.tracing.screen_brightness)"

if [ "$PROP_VALUE_SCREEN" = "off" ] || [ "$PROP_VALUE_BRIGHTNESS" = "0.0" ]; then
    fan_off_phase
fi

chmod 666 "$PWM" "$EN" 2>/dev/null
echo 1 > "$EN" || { echo "failed to set manual mode"; exit 1; }

# Kick sequence: ON/OFF pulses to overcome stiction, then steady ON
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
printf "pwm1=%s\n" "$(cat "$PWM")"

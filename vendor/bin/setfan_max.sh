#!/system/bin/sh

sleep 3

N="/sys/devices/platform/soc/soc:fan/hwmon/hwmon0"
PWM="$N/pwm1"
EN="$N/pwm1_enable"
TACH="$N/fan1_input"   # may or may not exist

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

# Basic safety: if nodes are missing, bail out
if [ ! -e "$PWM" ] || [ ! -e "$EN" ]; then
    echo "fan sysfs nodes not found: PWM=$PWM EN=$EN"
    exit 1
fi

chmod 666 "$PWM" "$EN" 2>/dev/null

# 1 = manual mode on this platform
echo 1 > "$EN" || { echo "failed to set manual mode"; exit 1; }

# Helper: read RPM if available, else 0
read_rpm() {
    if [ -r "$TACH" ]; then
        cat "$TACH" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Aggressive kick routine:
# - Several strong full-duty pulses with short OFF gaps.
# - If a tach is available and we detect > 200 RPM, stop kicking early.
kick_fan() {
    attempts=0
    max_attempts=5

    while [ $attempts -lt $max_attempts ]; do
        # Strong ON pulse
        echo 255 > "$PWM"
        # Longer ON time to overcome stiction
        usleep 900000   # 0.9s

        rpm=$(read_rpm)
        if [ "$rpm" -gt 200 ]; then
            # Fan is spinning, no need for further kicks
            break
        fi

        # Short OFF to let driver re-latch and give a "jerk" on next pulse
        echo 0 > "$PWM"
        usleep 200000   # 0.2s

        attempts=$((attempts + 1))
    done
}

# Run the aggressive kick sequence
kick_fan

# Hold at full speed once started
echo 255 > "$PWM"

printf "pwm1=%s\n" "$(cat "$PWM" 2>/dev/null)"
if [ -r "$TACH" ]; then
    printf "fan1_input(rpm)=%s\n" "$(cat "$TACH" 2>/dev/null)"
fi

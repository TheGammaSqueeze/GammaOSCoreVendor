#!/system/bin/sh

SYSFS=/sys/class/gpio5_pwm2

# 1) Sanity check
if [ ! -d "$SYSFS" ]; then
  echo "ERROR: PWM sysfs path not found: $SYSFS" >&2
  exit 1
fi

# 2) Read the period (ns)
period=$(cat "$SYSFS/period" 2>/dev/null)
#  Validate: non-empty and all digits
case "$period" in
  ''|*[!0-9]*)
    echo "ERROR: could not read valid period" >&2
    exit 1
    ;;
esac

# 3) Compute 50% duty
duty=$(( period / 2 ))

# 4) Write duty
if ! echo "$duty" > "$SYSFS/duty"; then
  echo "ERROR: failed to write duty" >&2
  exit 1
fi

# 5) Enable PWM
if ! echo 1 > "$SYSFS/state"; then
  echo "ERROR: failed to enable PWM" >&2
  exit 1
fi

echo "Fan set to 50% (duty=${duty}/${period} ns)"


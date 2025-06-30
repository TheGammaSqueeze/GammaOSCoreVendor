#!/system/bin/sh

SYSFS=/sys/class/gpio5_pwm2

# sanity check
if [ ! -d "$SYSFS" ]; then
  echo "ERROR: PWM sysfs path not found: $SYSFS" >&2
  exit 1
fi

# 1) Read the period (ns)
period=$(cat "$SYSFS/period")
if [ -z "$period" ]; then
  echo "ERROR: could not read period" >&2
  exit 1
fi

# 2) Set duty = period  100%
echo "$period" > "$SYSFS/duty" || {
  echo "ERROR: failed to write duty" >&2
  exit 1
}

# 3) Turn PWM on
echo 1 > "$SYSFS/state" || {
  echo "ERROR: failed to enable PWM" >&2
  exit 1
}

echo "Fan set to 100% (duty=${period}/${period} ns)"


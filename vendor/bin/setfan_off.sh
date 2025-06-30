#!/system/bin/sh

SYSFS=/sys/class/gpio5_pwm2

# 1) Sanity check
if [ ! -d "$SYSFS" ]; then
  echo "ERROR: PWM sysfs path not found: $SYSFS" >&2
  exit 1
fi

# 2) Disable PWM (stop toggling the GPIO)
echo 0 > "$SYSFS/state" || {
  echo "ERROR: failed to disable PWM" >&2
  exit 1
}

# 3) Restore default duty (10 000 ns)
#    This matches the DTS default: gpio5-pwm-duty-ns = <0x2710>;
echo 10000 > "$SYSFS/duty" || {
  echo "ERROR: failed to reset duty" >&2
  exit 1
}

echo "Fan PWM disabled; duty reset to 10000 ns (20%)"


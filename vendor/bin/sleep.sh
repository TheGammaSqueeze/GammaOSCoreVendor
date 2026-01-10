#!/system/bin/sh

STATE="/sys/power/state"
MEM_SLEEP="/sys/power/mem_sleep"
INTERVAL_SEC=10

# Disable broad PMIC and its subfunctions that can wake spuriously
for f in \
  /sys/devices/platform/fdd40000.i2c/i2c-0/0-0020/rk817-battery/power_supply/battery/power/wakeup \
  /sys/devices/platform/fdd40000.i2c/i2c-0/0-0020/rk817-charger/power_supply/ac/power/wakeup \
  /sys/devices/platform/fdd40000.i2c/i2c-0/0-0020/rk817-charger/power_supply/usb/power/wakeup \
  /sys/devices/platform/fdd40000.i2c/i2c-0/0-0020/rk808-rtc/power/wakeup \
  /sys/devices/platform/fdd40000.i2c/i2c-0/0-0020/rk808-rtc/rtc/rtc0/alarmtimer.0.auto/power/wakeup \
  /sys/devices/platform/fdd40000.i2c/i2c-0/0-0062/power_supply/cw2015-battery/power/wakeup \
  /sys/devices/platform/fdf80200.rkvdec/power/wakeup \
  /sys/devices/platform/fdef0000.iep/power/wakeup \
  /sys/devices/platform/fdf40000.rkvenc/power/wakeup \
  /sys/devices/platform/fdea0400.vdpu/power/wakeup \
  /sys/devices/platform/fded0000.jpegd/power/wakeup \
  /sys/devices/platform/fdeb0000.rk_rga/power/wakeup \
  /sys/devices/platform/fdee0000.vepu/power/wakeup
do
  [ -e "$f" ] && echo disabled > "$f"
done

# Re-enable only what we actually want
echo enabled > /sys/devices/platform/fdd40000.i2c/i2c-0/0-0020/rk805-pwrkey/power/wakeup
echo enabled > /sys/devices/platform/gpio-keys/power/wakeup
echo enabled > /sys/devices/platform/fdd40000.i2c/i2c-0/0-0020/power/wakeup

# Prefer deep if available
if [ -w "$MEM_SLEEP" ] && grep -q "deep" "$MEM_SLEEP" 2>/dev/null; then
  echo deep > "$MEM_SLEEP" 2>/dev/null
fi

# Periodically request suspend-to-RAM by writing "mem" to /sys/power/state.
while :; do
  # Request suspend-to-RAM
  echo mem > "$STATE" 2>/dev/null

  # If we immediately resume, wait and try again.
  sleep "$INTERVAL_SEC"
done

#!/system/bin/sh
# Ramp pwm_fan_set up to 255 in +1 steps every STEP_DELAY seconds.

FAN_SYSFS="/sys/devices/platform/pwm_fan/pwm_fan_set"
TARGET=255
STEP_DELAY=0.1

# Optional: set VERIFY_EVERY to a positive integer to re-read sysfs every N steps.
VERIFY_EVERY="${VERIFY_EVERY:-0}"

read_cur() {
  local v
  IFS= read -r v < "$FAN_SYSFS" 2>/dev/null || v=0
  v="${v%%[!0-9]*}"
  [ -n "$v" ] || v=0
  echo "$v"
}

cur="$(read_cur)"
[ "$cur" -ge "$TARGET" ] && { printf '%s\n' "$TARGET" > "$FAN_SYSFS" 2>/dev/null; exit 0; }

i=0
while [ "$cur" -lt "$TARGET" ]; do
  cur=$((cur + 1))
  printf '%s\n' "$cur" > "$FAN_SYSFS" 2>/dev/null

  if [ "$VERIFY_EVERY" -gt 0 ]; then
    i=$((i + 1))
    if [ $((i % VERIFY_EVERY)) -eq 0 ]; then
      cur="$(read_cur)"
      [ "$cur" -ge "$TARGET" ] && break
    fi
  fi

  sleep "$STEP_DELAY"
done

printf '%s\n' "$TARGET" > "$FAN_SYSFS" 2>/dev/null
#!/system/bin/sh

STATE="/sys/power/state"
MEM_SLEEP="/sys/power/mem_sleep"
INTERVAL_SEC=10

sleep 10

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

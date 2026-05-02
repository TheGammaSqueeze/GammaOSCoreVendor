#!/system/bin/sh

BIN=/vendor/bin/fan_fake_pwm

# Defaults for this profile
DEF_STRENGTH=80
DEF_DUTY=20
DEF_START=""

# Parameters:
#   $1 = target_strength
#   $2 = duty/on_ms
#   $3 = start_strength (optional)
strength="${1:-$DEF_STRENGTH}"
duty="${2:-$DEF_DUTY}"
start="${3:-$DEF_START}"

# Build argv safely (support optional start_strength)
if [ -n "$start" ]; then
  ARGS="$strength $duty $start"
else
  ARGS="$strength $duty"
fi

# Try to use real-time scheduling if available.
if command -v chrt >/dev/null 2>&1; then
  # SCHED_FIFO, priority 80 (1..99). Avoid 99 to reduce starvation risk.
  exec chrt -f 80 "$BIN" $ARGS
fi

# Fallback: best-effort nice level (not real-time).
# -20 is highest priority for normal scheduling.
if command -v renice >/dev/null 2>&1; then
  "$BIN" $ARGS &
  pid=$!
  renice -n -20 -p "$pid" >/dev/null 2>&1
  wait "$pid"
  exit $?
fi

exec "$BIN" $ARGS

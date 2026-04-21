#!/system/bin/sh
# Periodic watchdog for GPU power_policy drift and PLL stuck-state
# mitigation. Every POLL seconds, once the system is quiescent (no
# setclock_* service running, performance mode stable for DEBOUNCE
# seconds), reconciles power_policy to the mode-appropriate value:
# always_on under max, coarse_demand otherwise.
#
# Under max, an observed drift from always_on to coarse_demand implies
# the GPU may have power-gated and could have resumed into the
# stuck-at-1000 MHz PLL state (see rk3576_gpu_stuck_state), so
# setclock_max is re-fired via init to bounce the PLL.
#
# The DEBOUNCE gate exists because the Quick Settings tile cycles
# powersave -> stock -> max across successive taps; a tile sweep can
# produce rapid persist.gammaos.performance_mode changes. Without
# debounce the watchdog could bounce the PLL on a transient
# intermediate mode the user is only passing through.

GPU_DEV=/sys/devices/platform/27800000.gpu
POLICY=$GPU_DEV/power_policy
POLL=5
DEBOUNCE=5

read_active() {
  sed -n 's/.*\[\([^]]*\)\].*/\1/p' $POLICY 2>/dev/null
}

setclock_busy() {
  # Only the setclock scripts themselves touch sysfs. The _delayed
  # wrappers just sleep for 30s then fire the script, so excluding
  # them lets the watchdog reconcile drift during that window.
  for svc in setclock_max setclock_stock setclock_powersave; do
    if [ "$(getprop init.svc.$svc)" = "running" ]; then
      return 0
    fi
  done
  return 1
}

expected_policy_for() {
  case "$1" in
    max) echo always_on ;;
    *)   echo coarse_demand ;;
  esac
}

last_mode=
last_mode_ts=0

while true; do
  sleep $POLL

  now=$(date +%s)
  mode=$(getprop persist.gammaos.performance_mode)

  if [ "$mode" != "$last_mode" ]; then
    last_mode=$mode
    last_mode_ts=$now
    continue
  fi

  # Wait for mode to stabilise across rapid tile cycles.
  if [ $((now - last_mode_ts)) -lt $DEBOUNCE ]; then
    continue
  fi

  # Don't race with an in-flight setclock script.
  setclock_busy && continue

  expected=$(expected_policy_for "$mode")
  active=$(read_active)

  [ "$active" = "$expected" ] && continue

  echo $expected > $POLICY 2>/dev/null

  if [ "$mode" = "max" ]; then
    start setclock_max
  fi
done

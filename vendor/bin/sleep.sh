#!/system/bin/sh
# Ultra low power saving screen-off helper. Two modes:
#   sleep.sh            - turn the radios off (remembering the user's setting),
#                         then loop forcing suspend-to-RAM while the screen is off.
#   sleep.sh restore    - re-enable only the radios the user actually had on, then
#                         exit (run on screen-on).
# Started by init.gammaos_power.rc, gated on ultra_low_power_saving_mode + screen
# off + USB unplugged.

STATE="/sys/power/state"
MEM_SLEEP="/sys/power/mem_sleep"
INTERVAL_SEC=60
WIFI_FLAG="sys.gammaos.ulps.wifi_was"
BT_FLAG="sys.gammaos.ulps.bt_was"

if [ "$1" = "restore" ]; then
    # Re-enable only what was on before suspend; leave the rest off.
    [ "$(getprop $WIFI_FLAG)" = "1" ] && svc wifi enable
    [ "$(getprop $BT_FLAG)" = "1" ] && cmd bluetooth_manager enable
    setprop $WIFI_FLAG ""
    setprop $BT_FLAG ""
    exit 0
fi

# Remember the user's radio state, then power the radios down for the suspend
# window to save their idle/associated current. svc/cmd set the framework state,
# so the screen-on restore just re-enables what was on.
WIFI_WAS="$(settings get global wifi_on 2>/dev/null)"
BT_WAS="$(settings get global bluetooth_on 2>/dev/null)"
setprop $WIFI_FLAG "$WIFI_WAS"
setprop $BT_FLAG "$BT_WAS"
[ "$WIFI_WAS" = "1" ] && svc wifi disable
[ "$BT_WAS" = "1" ] && cmd bluetooth_manager disable
# Let the radio teardowns settle before forcing suspend.
sleep 2

# Prefer deep suspend if available.
if [ -w "$MEM_SLEEP" ] && grep -q "deep" "$MEM_SLEEP" 2>/dev/null; then
    echo deep > "$MEM_SLEEP" 2>/dev/null
fi

# Opportunistically suspend-to-RAM using the wakeup_count handshake. A blind
# "echo mem" races the wake path: it can suspend the instant a power button is
# pressed (losing the wake) and re-suspends every interval before the framework
# finishes waking, so the device needs repeated presses and many seconds to wake.
# Read wakeup_count, write it back (fails with EBUSY if a wake occurred since, or
# while a wakelock is held), and only request suspend if that handshake succeeds.
WC="/sys/power/wakeup_count"
while :; do
    count=$(cat "$WC" 2>/dev/null)
    if [ -n "$count" ] && echo "$count" > "$WC" 2>/dev/null; then
        echo mem > "$STATE" 2>/dev/null
    fi
    sleep "$INTERVAL_SEC"
done

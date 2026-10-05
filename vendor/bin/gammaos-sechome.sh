#!/vendor/bin/sh
# GammaOS: the framework does not auto-place a HOME task on the bottom panel
# (DP, logical display 1), so without this the bottom stays on a stale
# framebuffer (a frozen boot-animation frame). Launch the secondary home there
# once the framework is up. init services start with no PATH, so set one (am's
# wrapper also shells out to `cmd`). Verify the activity actually landed and
# retry across the boot window (the DP connector can come up late).
export PATH=/system/bin:/system/xbin:/vendor/bin
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done
sleep 6
n=0
while [ "$n" -lt 40 ]; do
    if dumpsys activity activities 2>/dev/null | grep -q "com.gammaos.secondaryhome/"; then
        break
    fi
    am start --display 1 -n com.gammaos.secondaryhome/.SecondaryHomeActivity >/dev/null 2>&1
    n=$((n+1))
    sleep 3
done

#!/vendor/bin/sh
# GammaOS RP Duo Lite: the forced-sleep launcher (init.gammaos_power.rc force_sleep). It used
# to be "sleep 5; start cpu_screen_off", but once the home switched its panels off properly
# the SoC autosuspends the moment the screen is off, and a monotonic sleep does not advance
# through a suspend: the 5 s never passed and sleep.sh never ran (the radios stayed on, Wi-Fi
# woke the SoC every second). Wait on the wall clock instead, one short step at a time, so
# every wake moves it on; then start the sleep script.
t=$(date +%s)
while [ $(( $(date +%s) - t )) -lt 5 ]; do
    [ "$(getprop sys.screen.state)" = "on" ] && exit 0
    sleep 1
done
start cpu_screen_off

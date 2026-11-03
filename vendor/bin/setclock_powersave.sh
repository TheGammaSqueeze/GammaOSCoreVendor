#!/vendor/bin/sh
# GammaOS RP Duo power-save clock policy: walt under capped maximums (cpus 0-2 1.2288 GHz,
# 3-6 1.4016 GHz, 7 1.4592 GHz, about 60 percent of each cluster's top) and the GPU at
# 724 MHz at most (power level 5). Screen off (init starts this on sys.screen.state=off
# whatever the mode; the mode script restores on screen on): every cluster and the GPU at
# their lowest point.
PROP_VALUE="$(getprop persist.gammaos.performance_mode)"
# Clusters (cpufreq policies): policy0 = cpus 0-2 (441.6 MHz .. 1843.2 MHz), policy3 = cpus
# 3-6 (480 MHz .. 2.4 GHz), policy7 = cpu 7 (480 MHz .. 2.8032 GHz); walt is the stock
# governor. On this kernel scaling_max_freq caps the cluster as it should (verified on
# policy7), unlike the Duo Lite's, so the modes write real minimums and maximums. GPU: kgsl
# power levels 0 (1150 MHz) .. 9 (259 MHz) under msm-adreno-tz; max_pwrlevel is the fastest
# level allowed, min_pwrlevel the slowest.
#
# The three policy scripts each re-apply for 20 s to outlast late writers; a mode switch
# inside that window must not leave two loops fighting, so the newest script claims the
# clocks and every older loop exits at its next iteration.
GEN="$$"
setprop sys.gammaos.clock_owner "$GEN"

# set_policy <policy> <governor> <min kHz> <max kHz>: the governor, then the limits in an
# order the kernel accepts whether they go up or down (min to the floor first, then max,
# then min).
set_policy() {
    P=/sys/devices/system/cpu/cpufreq/$1
    echo "$2" > $P/scaling_governor
    echo "$(cat $P/cpuinfo_min_freq)" > $P/scaling_min_freq
    echo "$4" > $P/scaling_max_freq
    echo "$3" > $P/scaling_min_freq
}
# set_gpu <fastest level> <slowest level>
set_gpu() {
    G=/sys/class/kgsl/kgsl-3d0
    echo "msm-adreno-tz" > $G/devfreq/governor
    echo "0" > $G/max_pwrlevel
    echo "9" > $G/min_pwrlevel
    echo "$1" > $G/max_pwrlevel
    echo "$2" > $G/min_pwrlevel
}

apply_powersave_settings() {
    set_policy policy0 walt 595200 1228800
    set_policy policy3 walt 633600 1401600
    set_policy policy7 walt 633600 1459200
    set_gpu 5 9
}
apply_screen_off_settings() {
    set_policy policy0 walt 441600 441600
    set_policy policy3 walt 480000 480000
    set_policy policy7 walt 480000 480000
    set_gpu 9 9
}
SCREEN="$(getprop sys.screen.state)"
if [ "$SCREEN" = "off" ]; then
    i=0
    while [ $i -lt 10 ]; do
        [ "$(getprop sys.gammaos.clock_owner)" = "$GEN" ] || exit 0
        # The screen came back: the mode script owns the clocks from here, never
        # re-apply the screen-off floor over a wake.
        [ "$(getprop sys.screen.state)" = "off" ] || exit 0
        apply_screen_off_settings
        sleep 2
        i=$((i + 1))
    done
elif [ "$PROP_VALUE" = "powersave" ]; then
    apply_powersave_settings
    i=0
    while [ $i -lt 10 ]; do
        [ "$(getprop sys.gammaos.clock_owner)" = "$GEN" ] || exit 0
        [ "$(getprop sys.screen.state)" = "off" ] && exit 0
        apply_powersave_settings
        sleep 2
        i=$((i + 1))
    done
fi

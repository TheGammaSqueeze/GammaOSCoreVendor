#!/vendor/bin/sh
# GammaOS RP Duo Lite (SM6125) max clock policy: everything pinned at the top OPP.
# The pin comes from the performance governor plus the minimum; scaling_max_freq is not
# written (on this kernel that write lands in scaling_min_freq, see setclock_stock.sh).
# kgsl pwrlevel 0 = 950 MHz.
PROP_VALUE="$(getprop persist.gammaos.performance_mode)"
# The three policy scripts each re-apply for 20 s to outlast late writers; a mode
# switch inside that window must not leave two loops fighting, so the newest script
# claims the clocks and every older loop exits at its next iteration.
GEN="$$"
setprop sys.gammaos.clock_owner "$GEN"
apply_performance_settings() {
    echo "0" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "0" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor
    echo "performance" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    echo "1804800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "performance" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
    echo "2016000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
}
if [ "$PROP_VALUE" = "max" ]; then
    i=0
    while [ $i -lt 10 ]; do
        [ "$(getprop sys.gammaos.clock_owner)" = "$GEN" ] || exit 0
        apply_performance_settings
        sleep 2
        i=$((i + 1))
    done
else
    apply_performance_settings
fi

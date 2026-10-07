#!/vendor/bin/sh
# GammaOS RP Duo Lite (SM6125) stock clock policy: the kernel's own DVFS.
#
# Never write scaling_max_freq on this kernel: the value lands in scaling_min_freq (the
# old script's "max 2016000" pinned the big cluster at 2.016 GHz and "max 1804800" the
# little one at 1.8 GHz, so stock behaved like max). Minimums here are the floors the
# stock firmware uses with its governors; the maximums are the hardware tables.
PROP_VALUE="$(getprop persist.gammaos.performance_mode)"
# The three policy scripts each re-apply for 20 s to outlast late writers; a mode
# switch inside that window must not leave two loops fighting, so the newest script
# claims the clocks and every older loop exits at its next iteration.
GEN="$$"
setprop sys.gammaos.clock_owner "$GEN"
apply_stock_settings() {
    echo "0" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "6" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor
    echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    echo "614400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "walt" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
    echo "1056000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
}
if [ "$PROP_VALUE" = "stock" ]; then
    i=0
    while [ $i -lt 10 ]; do
        [ "$(getprop sys.gammaos.clock_owner)" = "$GEN" ] || exit 0
        apply_stock_settings
        sleep 2
        i=$((i + 1))
    done
fi

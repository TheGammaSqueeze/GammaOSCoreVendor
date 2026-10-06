#!/system/bin/sh
# RP Duo Lite (SM6125) stock clocks: the GPU free between 320 and 950 MHz
# (pwrlevels 6..0), the little cluster from 1.6 GHz under schedutil, the big
# cluster from 1.06 GHz under walt.

PROP_VALUE="$(getprop persist.gammaos.performance_mode)"

apply_stock_settings() {
    echo "0" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "6" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor

    echo "1612800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "1804800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

    echo "1056000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "2016000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "walt" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
}

if [ "$PROP_VALUE" = "stock" ]; then
    i=0
    while [ $i -lt 10 ]; do
        apply_stock_settings
        sleep 2
        i=$((i + 1))
    done
fi

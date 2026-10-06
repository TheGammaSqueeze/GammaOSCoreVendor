#!/system/bin/sh
# RP Duo Lite (SM6125) power save: GPU capped at 465 MHz (pwrlevel 5), big
# cluster capped at 652.8 MHz, little cluster free under schedutil.

PROP_VALUE="$(getprop persist.gammaos.performance_mode)"

apply_powersave_settings() {
    echo "5" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "6" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor

    echo "1612800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "1804800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

    echo "300000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "652800" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "walt" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
}

if [ "$PROP_VALUE" = "powersave" ]; then
    i=0
    while [ $i -lt 10 ]; do
        apply_powersave_settings
        sleep 2
        i=$((i + 1))
    done
fi

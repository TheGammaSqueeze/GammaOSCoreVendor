#!/system/bin/sh
# RP Duo Lite (SM6125): everything at the top OPP. kgsl pwrlevel 0 = 950 MHz; the
# devfreq min_freq knob is not honoured by msm-adreno-tz on this kernel, the
# pwrlevel bounds are.

PROP_VALUE="$(getprop persist.gammaos.performance_mode)"

apply_performance_settings() {
    echo "0" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "0" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor

    echo "1804800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "1804800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "performance" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

    echo "2016000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "2016000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "performance" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
}

if [ "$PROP_VALUE" = "max" ]; then
    i=0
    while [ $i -lt 10 ]; do
        apply_performance_settings
        sleep 2
        i=$((i + 1))
    done
else
    apply_performance_settings
fi

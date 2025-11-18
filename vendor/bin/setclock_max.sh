#!/system/bin/sh

PROP_VALUE="$(getprop persist.gammaos.performance_mode)"

apply_performance_settings() {
    echo "1050000000" > /sys/devices/platform/soc/5900000.qcom,kgsl-3d0/devfreq/5900000.qcom,kgsl-3d0/min_freq
    echo "1050000000" > /sys/devices/platform/soc/5900000.qcom,kgsl-3d0/devfreq/5900000.qcom,kgsl-3d0/max_freq
    echo "msm-adreno-tz" > /sys/devices/platform/soc/5900000.qcom,kgsl-3d0/devfreq/5900000.qcom,kgsl-3d0/governor

    echo "2016000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "2016000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "performance" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

    echo "2112000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "2112000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
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

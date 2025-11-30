#!/system/bin/sh

sleep 1

PROP_VALUE="$(getprop persist.gammaos.performance_mode)"

apply_max_settings() {
    echo "925000000" > /sys/devices/platform/soc@3000000/1800000.gpu/devfreq/1800000.gpu/min_freq
    echo "925000000" > /sys/devices/platform/soc@3000000/1800000.gpu/devfreq/1800000.gpu/max_freq
    echo "performance" > /sys/devices/platform/soc@3000000/1800000.gpu/devfreq/1800000.gpu/governor

    echo "1584000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "1584000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "performance" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    echo "1584000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed

    echo "2100000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "2100000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "performance" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
    echo "2100000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed
}

if [ "$PROP_VALUE" = "max" ]; then
    i=0
    while [ $i -lt 10 ]; do
        apply_max_settings
        sleep 2
        i=$((i + 1))
    done
else
    apply_max_settings
fi

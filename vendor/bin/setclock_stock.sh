#!/system/bin/sh

sleep 1

PROP_VALUE="$(getprop persist.gammaos.performance_mode)"

apply_stock_settings() {
    echo "150000000" > /sys/devices/platform/soc@3000000/1800000.gpu/devfreq/1800000.gpu/min_freq
    echo "792000000" > /sys/devices/platform/soc@3000000/1800000.gpu/devfreq/1800000.gpu/max_freq
    echo "simple_ondemand" > /sys/devices/platform/soc@3000000/1800000.gpu/devfreq/1800000.gpu/governor

    echo "0" > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed
    echo "408000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "1584000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
    echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

    echo "0" > /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed
    echo "408000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "2100000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
}

if [ "$PROP_VALUE" = "stock" ]; then
    i=0
    while [ $i -lt 10 ]; do
        apply_stock_settings
        sleep 2
        i=$((i + 1))
    done
else
    apply_stock_settings
fi

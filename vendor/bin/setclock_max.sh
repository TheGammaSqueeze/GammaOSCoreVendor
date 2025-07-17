#!/system/bin/sh

sleep 1

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

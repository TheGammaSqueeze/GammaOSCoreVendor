#!/system/bin/sh

echo "384000000" > /sys/devices/platform/soc/soc:mm/23140000.gpu/devfreq/23140000.gpu/min_freq
echo "384000000" > /sys/devices/platform/soc/soc:mm/23140000.gpu/devfreq/23140000.gpu/max_freq
echo "powersave" > /sys/devices/platform/soc/soc:mm/23140000.gpu/devfreq/23140000.gpu/governor

echo "0" > /sys/devices/system/cpu/cpufreq/policy0/scaling_fix_freq
echo "614400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo "614400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo "powersave" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo "614400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed
echo "614400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_fix_freq

echo "0" > /sys/devices/system/cpu/cpufreq/policy4/scaling_fix_freq
echo "614400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
echo "614400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
echo "powersave" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
echo "614400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed
echo "614400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_fix_freq

echo "0" > /sys/devices/system/cpu/cpufreq/policy7/scaling_fix_freq
echo "614400" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
echo "614400" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq
echo "powersave" > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor
echo "614400" > /sys/devices/system/cpu/cpufreq/policy7/scaling_setspeed
echo "614400" > /sys/devices/system/cpu/cpufreq/policy7/scaling_fix_freq

echo "userspace" > /sys/class/devfreq/scene-frequency/governor
echo "533" > /sys/class/devfreq/scene-frequency/userspace/set_freq
echo "50" > /sys/class/devfreq/scene-frequency/polling_interval

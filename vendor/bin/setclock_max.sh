#!/system/bin/sh

echo "850000000" > /sys/devices/platform/soc/soc:mm/23140000.gpu/devfreq/23140000.gpu/min_freq
echo "850000000" > /sys/devices/platform/soc/soc:mm/23140000.gpu/devfreq/23140000.gpu/max_freq
echo "performance" > /sys/devices/platform/soc/soc:mm/23140000.gpu/devfreq/23140000.gpu/governor

echo "614400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo "2184000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo "performance" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo "2184000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed
echo "2184000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_fix_freq

echo "614400" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
echo "2301000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
echo "performance" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
echo "2301000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed
echo "2301000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_fix_freq

echo "614400" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
echo "2704000" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq
echo "performance" > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor
echo "2704000" > /sys/devices/system/cpu/cpufreq/policy7/scaling_setspeed
echo "2704000" > /sys/devices/system/cpu/cpufreq/policy7/scaling_fix_freq

echo "userspace" > /sys/class/devfreq/scene-frequency/governor
echo "1866" > /sys/class/devfreq/scene-frequency/userspace/set_freq
echo "50" > /sys/class/devfreq/scene-frequency/polling_interval

echo "210000" > /sys/devices/virtual/thermal/thermal_zone3/trip_point_0_temp
echo "210000" > /sys/devices/virtual/thermal/thermal_zone3/trip_point_1_temp
echo "210000" > /sys/devices/virtual/thermal/thermal_zone3/trip_point_2_temp

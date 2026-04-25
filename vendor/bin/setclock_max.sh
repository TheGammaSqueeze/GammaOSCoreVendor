#!/system/bin/sh

# GPU: 850 MHz
echo "850000000" > /sys/devices/platform/soc/soc:mm/60000000.gpu/devfreq/60000000.gpu/min_freq
echo "850000000" > /sys/devices/platform/soc/soc:mm/60000000.gpu/devfreq/60000000.gpu/max_freq
echo "performance" > /sys/devices/platform/soc/soc:mm/60000000.gpu/devfreq/60000000.gpu/governor

# CPU LITTLE cluster: 2002 MHz
echo "2002000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo "2002000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo "userspace" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo "2002000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed
echo "2002000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_fix_freq

# CPU BIG cluster: 2002 MHz
echo "2002000" > /sys/devices/system/cpu/cpufreq/policy6/scaling_min_freq
echo "2002000" > /sys/devices/system/cpu/cpufreq/policy6/scaling_max_freq
echo "userspace" > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
echo "2002000" > /sys/devices/system/cpu/cpufreq/policy6/scaling_setspeed
echo "2002000" > /sys/devices/system/cpu/cpufreq/policy6/scaling_fix_freq

# DDR scene-frequency unchanged
echo "userspace" > /sys/class/devfreq/scene-frequency/governor
echo "1866" > /sys/class/devfreq/scene-frequency/userspace/set_freq
echo "50" > /sys/class/devfreq/scene-frequency/polling_interval

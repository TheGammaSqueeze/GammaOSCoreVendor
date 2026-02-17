#!/system/bin/sh

echo powersave > /sys/devices/platform/27800000.gpu/devfreq/27800000.gpu/governor
echo 300000000 > /sys/devices/platform/27800000.gpu/devfreq/27800000.gpu/min_freq
echo 300000000 > /sys/devices/platform/27800000.gpu/devfreq/27800000.gpu/max_freq

echo powersave > /sys/devices/platform/27d00000.vop/devfreq/27d00000.vop/governor
echo 500000000 > /sys/devices/platform/27d00000.vop/devfreq/27d00000.vop/min_freq
echo 500000000 > /sys/devices/platform/27d00000.vop/devfreq/27d00000.vop/max_freq

echo powersave > /sys/devices/platform/dmc/devfreq/dmc/governor
echo 528000000 > /sys/devices/platform/dmc/devfreq/dmc/min_freq
echo 528000000 > /sys/devices/platform/dmc/devfreq/dmc/max_freq

echo schedutil > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 408000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo 816000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq

echo schedutil > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
echo 408000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
echo 816000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq

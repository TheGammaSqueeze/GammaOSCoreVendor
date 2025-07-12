#!/system/bin/sh

sleep 1

echo "1100000000" > /sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali/min_freq
echo "1100000000" > /sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali/max_freq
echo "performance" > /sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali/governor

echo "500000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo "2000000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo "sugov_ext" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

echo "725000" > /sys/devices/system/cpu/cpufreq/policy6/scaling_min_freq
echo "2200000" > /sys/devices/system/cpu/cpufreq/policy6/scaling_max_freq
echo "sugov_ext" > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor

echo "800000000" > /sys/devices/platform/soc/10012000.dvfsrc/mtk-dvfsrc-devfreq/devfreq/mtk-dvfsrc-devfreq/min_freq
echo "4266000000" > /sys/devices/platform/soc/10012000.dvfsrc/mtk-dvfsrc-devfreq/devfreq/mtk-dvfsrc-devfreq/max_freq
echo "userspace" > /sys/devices/platform/soc/10012000.dvfsrc/mtk-dvfsrc-devfreq/devfreq/mtk-dvfsrc-devfreq/governor

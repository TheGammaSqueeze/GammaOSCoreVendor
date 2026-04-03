#!/system/bin/sh

echo performance > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/governor
echo 900000000 > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/min_freq
echo 900000000 > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/max_freq

echo performance > /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec/governor
echo 400000000 > /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec/min_freq
echo 400000000 > /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec/max_freq

echo performance > /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop/governor
echo 500000000 > /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop/min_freq
echo 500000000 > /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop/max_freq

echo performance > /sys/devices/platform/dmc/devfreq/dmc/governor
echo 920000000 > /sys/devices/platform/dmc/devfreq/dmc/min_freq
echo 920000000 > /sys/devices/platform/dmc/devfreq/dmc/max_freq

echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 2088638 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo 2088638 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq

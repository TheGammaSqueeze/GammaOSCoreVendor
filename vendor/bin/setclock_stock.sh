#!/system/bin/sh

echo simple_ondemand > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/governor
echo 200000000 > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/min_freq
echo 900000000 > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/max_freq

echo vdec2_ondemand > /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec/governor
echo 297000000 > /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec/min_freq
echo 400000000 > /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec/max_freq

echo vop2_ondemand > /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop/governor
echo 396000000 > /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop/min_freq
echo 500000000 > /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop/max_freq

echo dmc_ondemand > /sys/devices/platform/dmc/devfreq/dmc/governor
echo 324000000 > /sys/devices/platform/dmc/devfreq/dmc/min_freq
echo 920000000 > /sys/devices/platform/dmc/devfreq/dmc/max_freq

echo schedutil > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 408000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo 2160000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq

#!/system/bin/sh

echo 1 > /sys/class/leds/backlight_1_power/brightness
echo 1 > /sys/devices/platform/singleadc-joypad/enable
echo performance > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/governor
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

echo performance > /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec/governor
echo performance > /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop/governor
echo performance > /sys/devices/platform/dmc/devfreq/dmc/governor
echo performance > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/governor
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

echo 1992000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo 1992000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq

echo performance > /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec/governor
echo performance > /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop/governor
echo performance > /sys/devices/platform/dmc/devfreq/dmc/governor
echo performance > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/governor
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

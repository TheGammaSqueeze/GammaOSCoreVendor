#!/system/bin/sh

echo 1 > /sys/class/leds/backlight_1_power/brightness
echo 1 > /sys/devices/platform/singleadc-joypad/enable
echo performance > /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu/governor
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

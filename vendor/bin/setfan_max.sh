#!/system/bin/sh

echo 1 > /sys/devices/platform/odm/odm:mid_custom/fan
echo 500 > /sys/devices/platform/odm/odm:mid_custom/fan_pwm

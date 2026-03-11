#!/system/bin/sh

echo 0 > /sys/devices/platform/odm/odm:fan_controller/fpower
echo 0 > /sys/devices/platform/odm/odm:fan_controller/duty
echo 0 > /sys/devices/platform/odm/odm:fan_controller/preset_duty

#!/system/bin/sh

echo 1  > /sys/devices/platform/odm/odm:fan_controller/fpower
echo 99 > /sys/devices/platform/odm/odm:fan_controller/duty
echo 99 > /sys/devices/platform/odm/odm:fan_controller/preset_duty

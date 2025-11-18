#!/system/bin/sh

PWM="/sys/devices/platform/soc/soc:fan/hwmon/hwmon0/pwm1"

i=0
while [ $i -lt 20 ]; do
    echo 0 > "$PWM"
    i=$((i + 1))
    sleep 0.5
done

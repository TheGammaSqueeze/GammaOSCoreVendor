#!/system/bin/sh
# Fan off for the RG 55G1. 40 is the driver's minimum duty; at 40 the
# fan does not spin (0 RPM), so this is effectively off. Writing below
# 40 is clamped to 40 by the driver anyway.
echo 40 > /sys/class/gpio_pwm/duty

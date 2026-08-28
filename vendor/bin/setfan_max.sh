#!/system/bin/sh
# Fan full speed for the RG 55G1. The fan is a PWM fan on the gpio_pwm
# driver; duty is an 8-bit value (valid 40..255, values <40 or >255 are
# clamped by the driver to the 40 floor). 255 = maximum, ~7500 RPM.
echo 255 > /sys/class/gpio_pwm/duty

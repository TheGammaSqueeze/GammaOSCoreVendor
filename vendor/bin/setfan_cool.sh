#!/system/bin/sh
# Fan partial (quiet cooling) for the RG 55G1. duty 200 keeps the fan
# spinning for steady airflow without running at the full ~7500 RPM.
# (8-bit scale, valid 40..255; the fan only spins above roughly mid-scale.)
echo 200 > /sys/class/gpio_pwm/duty

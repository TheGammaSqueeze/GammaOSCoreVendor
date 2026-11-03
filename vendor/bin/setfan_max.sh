#!/system/bin/sh
# RP Duo fan: full speed.
# The fan is the gpio5_pwm driver at /sys/class/gpio5_pwm2: state 0/1, duty 0..10000
# (there is no period node; 10000 = full speed) and speed, the tach in rpm. Measured on the
# RP Duo: duty 2500 starts it from a stop (660 rpm), 5000 gives 1770, 10000 3750 rpm;
# 2000 and below does not start it.
C=/sys/class/gpio5_pwm2
i=0
while [ $i -lt 10 ]; do
    echo 10000 > $C/duty
    echo 1 > $C/state
    i=$((i + 1))
    sleep 1
done

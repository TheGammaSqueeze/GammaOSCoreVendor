#!/system/bin/sh
# RP Duo Lite fan: the gpio5_pwm kernel driver (TLMM gpio45 on the GP1 clock as
# PWM, gpio1 enable). /sys/class/gpio5_pwm2: state 0/1, duty and period in ns
# (period 50000 = 20 kHz). Full speed.
C=/sys/class/gpio5_pwm2
P="$(cat $C/period 2>/dev/null)"; [ -n "$P" ] || P=50000
i=0
while [ $i -lt 10 ]; do
    echo "$P" > $C/duty
    echo 1 > $C/state
    i=$((i + 1))
    sleep 1
done

#!/system/bin/sh
# RP Duo Lite fan off.
C=/sys/class/gpio5_pwm2
i=0
while [ $i -lt 10 ]; do
    echo 0 > $C/state
    i=$((i + 1))
    sleep 0.5
done

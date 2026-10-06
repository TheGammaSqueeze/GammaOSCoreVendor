#!/system/bin/sh
# RP Duo Lite fan, quiet profile: 60 percent duty ($1 overrides the percentage).
C=/sys/class/gpio5_pwm2
PCT="${1:-60}"
P="$(cat $C/period 2>/dev/null)"; [ -n "$P" ] || P=50000
D=$(( P * PCT / 100 ))
i=0
while [ $i -lt 10 ]; do
    echo "$D" > $C/duty
    echo 1 > $C/state
    i=$((i + 1))
    sleep 1
done

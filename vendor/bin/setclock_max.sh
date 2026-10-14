#!/vendor/bin/sh
# GammaOS RP Duo Lite (SM6125) max clock policy: everything pinned at the top OPP.
# The pin comes from the performance governor plus the minimum; scaling_max_freq is not
# written (on this kernel that write lands in scaling_min_freq, see setclock_stock.sh).
# kgsl pwrlevel 0 = 950 MHz.
PROP_VALUE="$(getprop persist.gammaos.performance_mode)"
# The three policy scripts each re-apply for 20 s to outlast late writers; a mode
# switch inside that window must not leave two loops fighting, so the newest script
# claims the clocks and every older loop exits at its next iteration.
GEN="$$"
setprop sys.gammaos.clock_owner "$GEN"
# Thermal caps. The board's quiet-therm thermistor zone throttles the big cluster and the
# GPU from 45 to 52 C (trips 1..11), which this handheld reaches within minutes of play:
# the GPU devfreq ceiling dropped to 600 MHz and then 320 MHz and the bottom panel fell to
# 30 fps in every mode but max (max pins the GPU below the ceiling). Lift every quiet-therm
# trip to 125 C and release the cooling states it asserted. The SoC junction zones (gpu,
# cpuss, cdsp ... at 95 to 125 C) stay armed, so real overheating still throttles.
lift_thermal_caps() {
    for z in /sys/class/thermal/thermal_zone*; do
        [ "$(cat $z/type 2>/dev/null)" = "quiet-therm" ] || continue
        echo enabled > $z/mode
        for t in $z/trip_point_*_temp; do
            echo 125000 > $t
        done
    done
    for c in /sys/class/thermal/cooling_device*; do
        case "$(cat $c/type 2>/dev/null)" in
            cpufreq-cpu0|cpufreq-cpu4|*kgsl*) echo 0 > $c/cur_state ;;
        esac
    done
}

apply_performance_settings() {
    echo "0" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "0" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor
    echo "performance" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    echo "1804800" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "performance" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
    echo "2016000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "0-3" > /dev/cpuset/display/cpus
}
lift_thermal_caps
if [ "$PROP_VALUE" = "max" ]; then
    i=0
    while [ $i -lt 10 ]; do
        [ "$(getprop sys.gammaos.clock_owner)" = "$GEN" ] || exit 0
        apply_performance_settings
        sleep 2
        i=$((i + 1))
    done
else
    apply_performance_settings
fi

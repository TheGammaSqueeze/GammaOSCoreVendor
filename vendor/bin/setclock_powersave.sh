#!/vendor/bin/sh
# GammaOS RP Duo Lite (SM6125) power-save clock policy.
#
# On this kernel a write to scaling_max_freq does NOT lower the cluster's maximum: the
# value lands in scaling_min_freq instead (verified on both clusters, perf HAL stopped
# or not), so the old script left the big cluster at 2.016 GHz with its minimum RAISED.
# The cap that works is the governor: "powersave" runs a cluster at its scaling_min_freq.
#
# Screen on: the little cluster is pinned at 1.3 GHz, the big one at 652.8 MHz and the
# GPU at 745 MHz (pwrlevel 3). Those are the lowest pins that keep both panels at 60 fps
# with a 4K video on the top panel and a game on the bottom (little 1.0 GHz or GPU 600 MHz
# fell to 30 fps). Screen off (init starts this on sys.screen.state=off whatever the mode;
# the mode script restores on screen on): everything at its lowest point as before.
PROP_VALUE="$(getprop persist.gammaos.performance_mode)"
# The three policy scripts each re-apply for 20 s to outlast late writers; a mode
# switch inside that window must not leave two loops fighting, so the newest script
# claims the clocks and every older loop exits at its next iteration.
GEN="$$"
setprop sys.gammaos.clock_owner "$GEN"
SCREEN="$(getprop sys.screen.state)"
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

apply_powersave_settings() {
    echo "3" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "3" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor
    echo "1305600" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "powersave" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    echo "652800" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "powersave" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
    echo "0-3" > /dev/cpuset/display/cpus
}
apply_screen_off_settings() {
    echo "5" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "6" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor
    echo "614400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "powersave" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    echo "652800" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "powersave" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
    echo "0-3" > /dev/cpuset/display/cpus
}
if [ "$SCREEN" = "off" ]; then
    i=0
    while [ $i -lt 10 ]; do
        [ "$(getprop sys.gammaos.clock_owner)" = "$GEN" ] || exit 0
        apply_screen_off_settings
        sleep 2
        i=$((i + 1))
    done
elif [ "$PROP_VALUE" = "powersave" ]; then
    lift_thermal_caps
    i=0
    while [ $i -lt 10 ]; do
        [ "$(getprop sys.gammaos.clock_owner)" = "$GEN" ] || exit 0
        apply_powersave_settings
        sleep 2
        i=$((i + 1))
    done
fi

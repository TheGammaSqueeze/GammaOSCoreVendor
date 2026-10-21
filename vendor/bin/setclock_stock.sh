#!/vendor/bin/sh
# GammaOS RP Duo Lite (SM6125) stock clock policy: the kernel's own CPU DVFS, with a GPU
# floor and the display threads on the big cluster.
#
# Never write scaling_max_freq on this kernel: the value lands in scaling_min_freq (the
# old script's "max 2016000" pinned the big cluster at 2.016 GHz and "max 1804800" the
# little one at 1.8 GHz, so stock behaved like max). Minimums here are the floors the
# stock firmware uses with its governors; the maximums are the hardware tables.
#
# GPU: the msm-adreno-tz governor does not ramp for SurfaceFlinger's composition load (it
# sat at 320 MHz while every frame missed with a 4K video on the top panel and a game on
# the bottom), so stock keeps a 600 MHz floor (pwrlevel 4) under the governor. Measured
# with that scene: floor 6 = 183 of 183 frames missed, floor 4 + display threads on the
# big cluster = 0 of 366 missed. The display cpuset (SurfaceFlinger main, RenderEngine
# and the composer) moves to cpus 4-7 here; the GPU composition wait on the little cores
# missed frames even at 950 MHz.
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

apply_stock_settings() {
    echo "0" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "4" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor
    echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    echo "614400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "walt" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
    echo "1056000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "4-7" > /dev/cpuset/display/cpus
}
if [ "$PROP_VALUE" = "stock" ]; then
    # Clocks first, thermal caps after: the zone scan takes seconds on a loaded system
    # and the wake from sleep must not sit at the screen-off clocks while it runs.
    apply_stock_settings
    lift_thermal_caps
    i=0
    while [ $i -lt 10 ]; do
        [ "$(getprop sys.gammaos.clock_owner)" = "$GEN" ] || exit 0
        [ "$(getprop sys.screen.state)" = "off" ] && exit 0
        apply_stock_settings
        sleep 2
        i=$((i + 1))
    done
fi

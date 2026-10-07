#!/vendor/bin/sh
# GammaOS RP Duo Lite (SM6125) power-save clock policy.
#
# On this kernel a write to scaling_max_freq does NOT lower the cluster's maximum: the
# value lands in scaling_min_freq instead (verified on both clusters, perf HAL stopped
# or not), so the old script left the big cluster at 2.016 GHz with its minimum RAISED.
# The cap that works is the governor: "powersave" runs a cluster at its scaling_min_freq,
# so the big cluster is pinned at 652.8 MHz and the little one at 614.4 MHz here, with the
# GPU capped at 465 MHz through its own power levels (0 = 950 MHz ... 6 = 320 MHz).
# Applied when the user's mode is powersave, and also while the screen is off whatever the
# mode (init starts this on sys.screen.state=off; the mode script restores on screen on).
PROP_VALUE="$(getprop persist.gammaos.performance_mode)"
# The three policy scripts each re-apply for 20 s to outlast late writers; a mode
# switch inside that window must not leave two loops fighting, so the newest script
# claims the clocks and every older loop exits at its next iteration.
GEN="$$"
setprop sys.gammaos.clock_owner "$GEN"
SCREEN="$(getprop sys.screen.state)"
apply_powersave_settings() {
    echo "5" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
    echo "6" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
    echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor
    echo "614400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
    echo "powersave" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    echo "652800" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
    echo "powersave" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
}
if [ "$PROP_VALUE" = "powersave" ] || [ "$SCREEN" = "off" ]; then
    i=0
    while [ $i -lt 10 ]; do
        [ "$(getprop sys.gammaos.clock_owner)" = "$GEN" ] || exit 0
        apply_powersave_settings
        sleep 2
        i=$((i + 1))
    done
fi

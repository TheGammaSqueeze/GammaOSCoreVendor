#!/system/bin/sh

# Set every scalable domain to its highest available OPP.
# Frequencies are read from the kernel instead of hardcoded so the same
# script works across SoC bins / DVFS tables.

max_of() {
    # max_of "<space separated list>"
    echo "$1" | awk '{m=$1; for (i=1;i<=NF;i++) if ($i>m) m=$i; print m}'
}

set_devfreq_top() {
    base=$1
    [ -d "$base" ] || return
    top=$(max_of "$(cat $base/available_frequencies)")
    [ -n "$top" ] || return
    echo performance > $base/governor
    # raise max before min so we never try to push min above the current max
    echo $top > $base/max_freq
    echo $top > $base/min_freq
}

set_devfreq_top /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu
set_devfreq_top /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec
set_devfreq_top /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop
set_devfreq_top /sys/devices/platform/dmc/devfreq/dmc

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$policy" ] || continue
    top=$(cat $policy/cpuinfo_max_freq)
    echo performance > $policy/scaling_governor
    echo $top > $policy/scaling_max_freq
    echo $top > $policy/scaling_min_freq
done

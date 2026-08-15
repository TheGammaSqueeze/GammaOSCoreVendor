#!/system/bin/sh

# Restore stock DVFS: each domain back on its ondemand-style governor with the
# min/max clamps opened up to the full available OPP range. Frequencies are read
# from the kernel instead of hardcoded so the same script works across SoC bins.

min_of() {
    echo "$1" | awk '{m=$1; for (i=1;i<=NF;i++) if ($i<m) m=$i; print m}'
}
max_of() {
    echo "$1" | awk '{m=$1; for (i=1;i<=NF;i++) if ($i>m) m=$i; print m}'
}

set_devfreq_stock() {
    base=$1
    gov=$2
    [ -d "$base" ] || return
    freqs=$(cat $base/available_frequencies)
    lo=$(min_of "$freqs")
    hi=$(max_of "$freqs")
    [ -n "$hi" ] || return
    echo $gov > $base/governor
    echo $hi > $base/max_freq
    echo $lo > $base/min_freq
}

set_devfreq_stock /sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu       simple_ondemand
set_devfreq_stock /sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec vdec2_ondemand
set_devfreq_stock /sys/devices/platform/fe040000.vop/devfreq/fe040000.vop       vop2_ondemand
set_devfreq_stock /sys/devices/platform/dmc/devfreq/dmc                         dmc_ondemand

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$policy" ] || continue
    lo=$(cat $policy/cpuinfo_min_freq)
    hi=$(cat $policy/cpuinfo_max_freq)
    echo schedutil > $policy/scaling_governor
    echo $hi > $policy/scaling_max_freq
    echo $lo > $policy/scaling_min_freq
done

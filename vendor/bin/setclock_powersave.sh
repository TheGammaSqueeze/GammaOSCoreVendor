#!/system/bin/sh

# Powersave DVFS: hold each domain low. Every frequency below is resolved against
# the OPPs the kernel actually exposes, because a value that is not an available
# OPP does not clamp - it is silently ignored and the domain stays wherever it
# was, which on a device coming out of setclock_max.sh means pinned at its
# ceiling. That is exactly what happened before: this script asked the RG DS Plus
# for a 920 MHz DMC cap (an RG DS frequency; the Plus has 324/528/780/1056 and no
# 920), so the Plus ran its memory at 1056 MHz in "powersave" indefinitely. The
# RG DS had the same problem on the VOP, which only offers 500 MHz here.
#
# Write order matters too: a max_freq below the current min_freq is rejected, so
# the floor is dropped to the lowest OPP before the ceiling is lowered.

# highest available OPP that is <= $1; falls back to the lowest OPP
pick_le() {
    target=$1
    shift
    echo "$@" | awk -v t="$target" '{
        best = ""; lo = "";
        for (i = 1; i <= NF; i++) {
            if (lo == "" || $i < lo) lo = $i;
            if ($i <= t && (best == "" || $i > best)) best = $i;
        }
        print (best == "" ? lo : best);
    }'
}

min_of() { echo "$1" | awk '{m=$1; for (i=1;i<=NF;i++) if ($i<m) m=$i; print m}'; }

# set_devfreq <base> <governor> <min target> <max target>
set_devfreq() {
    base=$1; gov=$2; mintgt=$3; maxtgt=$4
    [ -d "$base" ] || return
    freqs=$(cat $base/available_frequencies 2>/dev/null)
    [ -n "$freqs" ] || return
    lo=$(min_of "$freqs")
    minf=$(pick_le "$mintgt" "$freqs")
    maxf=$(pick_le "$maxtgt" "$freqs")
    echo $gov > $base/governor 2>/dev/null
    echo $lo > $base/min_freq 2>/dev/null
    echo $maxf > $base/max_freq 2>/dev/null
    echo $minf > $base/min_freq 2>/dev/null
}

GPU=/sys/devices/platform/fde60000.gpu/devfreq/fde60000.gpu
VDEC=/sys/devices/platform/fdf80200.rkvdec/devfreq/fdf80200.rkvdec
VOP=/sys/devices/platform/fe040000.vop/devfreq/fe040000.vop
DMC=/sys/devices/platform/dmc/devfreq/dmc

# GPU: let it idle at its floor, cap around 400 MHz.
set_devfreq $GPU simple_ondemand 200000000 400000000

# Video decoder: its own floor.
set_devfreq $VDEC vdec2_ondemand 297000000 297000000

# Display controller: its lowest OPP (396 MHz on the Plus, 500 MHz on the RG DS,
# which has only the one).
set_devfreq $VOP vop2_ondemand 0 0

# Memory: pinned at 780 MHz. Both devices have that OPP; the step above it is
# 920 MHz on the RG DS and 1056 MHz on the Plus.
set_devfreq $DMC dmc_ondemand 780000000 780000000

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$policy" ] || continue
    lo=$(cat $policy/cpuinfo_min_freq)
    echo schedutil > $policy/scaling_governor
    echo $lo > $policy/scaling_min_freq
    echo 1416000 > $policy/scaling_max_freq
    echo $lo > $policy/scaling_min_freq
done

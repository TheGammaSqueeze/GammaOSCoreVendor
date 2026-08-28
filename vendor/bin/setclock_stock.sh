#!/system/bin/sh
# Stock (dynamic) profile for the RG 55G1 (SM4450 / Adreno 613). Each
# rail scales across its full range under a dynamic governor, matching
# the device's out-of-box behaviour.
#
# Write order: governor, then min-low, then max-target. Robust across
# starting states (powersave-left, max-left, already-pinned) without
# min>max kernel rejections.

GPU=/sys/class/kgsl/kgsl-3d0/devfreq
P0=/sys/devices/system/cpu/cpufreq/policy0
P6=/sys/devices/system/cpu/cpufreq/policy6

# GPU: dynamic across 340..1010 MHz
echo simple_ondemand > $GPU/governor
echo 340000000  > $GPU/min_freq
echo 1010000000 > $GPU/max_freq

# CPU cluster 0 (little): dynamic across 499.2..1958.4 MHz
echo walt   > $P0/scaling_governor
echo 499200  > $P0/scaling_min_freq
echo 1958400 > $P0/scaling_max_freq

# CPU cluster 1 (big): dynamic across 691.2..2400 MHz
echo walt   > $P6/scaling_governor
echo 691200  > $P6/scaling_min_freq
echo 2400000 > $P6/scaling_max_freq

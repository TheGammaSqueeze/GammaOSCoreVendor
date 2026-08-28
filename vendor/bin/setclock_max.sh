#!/system/bin/sh
# Max performance profile for the RG 55G1 (Qualcomm SM4450 "ravelin",
# Adreno 613). Pins the GPU to its top OPP (1010 MHz, the hardware /
# GMU-ACD ceiling) and both CPU clusters to their top frequencies.
#
# Write order per rail: governor first, then min to its lowest valid
# OPP, then max to the ceiling, then min up to the pin target. This is
# robust across any starting state (powersave-left, framework-set,
# already-pinned) without min>max kernel rejections.

GPU=/sys/class/kgsl/kgsl-3d0/devfreq
P0=/sys/devices/system/cpu/cpufreq/policy0
P6=/sys/devices/system/cpu/cpufreq/policy6

# GPU: pin 1010 MHz (levels: 1010 955 850 765 605 500 340 MHz)
echo performance > $GPU/governor
echo 340000000  > $GPU/min_freq
echo 1010000000 > $GPU/max_freq
echo 1010000000 > $GPU/min_freq

# CPU cluster 0 (little, cpu0-5): pin 1958.4 MHz
echo performance > $P0/scaling_governor
echo 499200  > $P0/scaling_min_freq
echo 1958400 > $P0/scaling_max_freq
echo 1958400 > $P0/scaling_min_freq

# CPU cluster 1 (big, cpu6-7): pin 2400 MHz
echo performance > $P6/scaling_governor
echo 691200  > $P6/scaling_min_freq
echo 2400000 > $P6/scaling_max_freq
echo 2400000 > $P6/scaling_min_freq

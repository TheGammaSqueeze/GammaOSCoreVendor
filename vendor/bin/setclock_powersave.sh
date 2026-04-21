#!/system/bin/sh
# Power-saving profile. No GPU bounce needed here because the target is
# 300 MHz (half-speed vs full-speed does not matter at that clock). On exit
# to stock or max, those scripts run the unstick bounce themselves.
# All min/max writes drop min first for safe transitions from any profile.

GPU=/sys/devices/platform/27800000.gpu/devfreq/27800000.gpu
VOP=/sys/devices/platform/27d00000.vop/devfreq/27d00000.vop
DMC=/sys/devices/platform/dmc/devfreq/dmc
P0=/sys/devices/system/cpu/cpufreq/policy0
P4=/sys/devices/system/cpu/cpufreq/policy4

echo powersave > $GPU/governor
echo 300000000 > $GPU/min_freq
echo 300000000 > $GPU/max_freq

echo powersave > $VOP/governor
echo 500000000 > $VOP/min_freq
echo 500000000 > $VOP/max_freq

echo powersave > $DMC/governor
echo 528000000 > $DMC/min_freq
echo 528000000 > $DMC/max_freq

echo schedutil > $P0/scaling_governor
echo 408000 > $P0/scaling_min_freq
echo 816000 > $P0/scaling_max_freq

echo schedutil > $P4/scaling_governor
echo 408000 > $P4/scaling_min_freq
echo 816000 > $P4/scaling_max_freq

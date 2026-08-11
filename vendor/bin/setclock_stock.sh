#!/system/bin/sh
# Stock (dynamic) profile at non-OC ceilings. All rails scale within
# their non-OC ranges. GPU max stays at 900 MHz, so the stuck-at-1000
# PLL state (see rk3576_gpu_stuck_state) cannot manifest here; no
# unstick bounce or always_on power policy is required.
#
# Write order: governor, then min-low, then max-target. Robust across
# starting states (powersave-left, max-left, already-pinned) without
# min>max kernel rejections.

GPU=/sys/devices/platform/27800000.gpu/devfreq/27800000.gpu
GPU_DEV=/sys/devices/platform/27800000.gpu
VOP=/sys/devices/platform/27d00000.vop/devfreq/27d00000.vop
DMC=/sys/devices/platform/dmc/devfreq/dmc
P0=/sys/devices/system/cpu/cpufreq/policy0
P4=/sys/devices/system/cpu/cpufreq/policy4

echo simple_ondemand > $GPU/governor
echo 300000000 > $GPU/min_freq
echo 900000000 > $GPU/max_freq

echo vop2_ondemand > $VOP/governor
echo 500000000 > $VOP/min_freq
echo 702000000 > $VOP/max_freq

echo dmc_ondemand > $DMC/governor
echo 528000000  > $DMC/min_freq
echo 2112000000 > $DMC/max_freq

echo schedutil > $P0/scaling_governor
echo 408000  > $P0/scaling_min_freq
echo 2016000 > $P0/scaling_max_freq

echo schedutil > $P4/scaling_governor
echo 408000  > $P4/scaling_min_freq
echo 2208000 > $P4/scaling_max_freq

# Restore default power policy. always_on only matters when GPU can hit
# 1000 MHz; at stock's 900 max there is no stuck-on-resume risk, and
# coarse_demand saves idle power. Explicit in case we switched here
# from the max profile which pins always_on.
echo coarse_demand > $GPU_DEV/power_policy

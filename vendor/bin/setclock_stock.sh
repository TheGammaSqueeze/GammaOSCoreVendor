#!/system/bin/sh
# Stock (dynamic) profile. GPU gets an unstick bounce, then hands off to
# simple_ondemand with min_freq raised to 700 MHz so idle cycling does not
# drop the GPU into the 300/400 MHz OPPs that trigger the Mali half-speed
# PLL state (see rk3576_gpu_stuck_state).

GPU=/sys/devices/platform/27800000.gpu/devfreq/27800000.gpu
VOP=/sys/devices/platform/27d00000.vop/devfreq/27d00000.vop
DMC=/sys/devices/platform/dmc/devfreq/dmc
P0=/sys/devices/system/cpu/cpufreq/policy0
P4=/sys/devices/system/cpu/cpufreq/policy4

echo performance > $GPU/governor
echo 300000000  > $GPU/min_freq
echo 900000000  > $GPU/max_freq
echo 900000000  > $GPU/min_freq
echo 1000000000 > $GPU/max_freq
echo 1000000000 > $GPU/min_freq
echo simple_ondemand > $GPU/governor
echo 700000000  > $GPU/min_freq
echo 1000000000 > $GPU/max_freq

echo vop2_ondemand > $VOP/governor
echo 500000000 > $VOP/min_freq
echo 702000000 > $VOP/max_freq

echo dmc_ondemand > $DMC/governor
echo 528000000 > $DMC/min_freq
echo 2112000000 > $DMC/max_freq

echo schedutil > $P0/scaling_governor
echo 408000 > $P0/scaling_min_freq
echo 2208000 > $P0/scaling_max_freq

echo schedutil > $P4/scaling_governor
echo 408000 > $P4/scaling_min_freq
echo 2304000 > $P4/scaling_max_freq

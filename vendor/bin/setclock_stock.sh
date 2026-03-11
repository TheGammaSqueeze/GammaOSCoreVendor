#!/system/bin/sh

# CPU governor: schedutil (dynamic) for both clusters
echo schedutil > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo schedutil > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor

# CPU full frequency range
echo 500000  > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 2000000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 774000  > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq
echo 2050000 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq

# PPM: unfix both clusters (dynamic scheduling)
echo "-1 -1" > /proc/ppm/policy/ut_fix_freq_idx

# GPU: disable fixed OPP (dynamic scaling)
echo 0 > /proc/gpufreq/gpufreq_opp_freq

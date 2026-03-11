#!/system/bin/sh

# CPU governor: performance for both clusters
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo performance > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor

# CPU max frequencies
echo 2000000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 2050000 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq

# Lock min to max (prevent downclocking)
echo 2000000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 2050000 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq

# PPM: fix both clusters to index 0 (max freq)
echo "0 0" > /proc/ppm/policy/ut_fix_freq_idx

# GPU: fix to max OPP (950 MHz)
echo 950000 > /proc/gpufreq/gpufreq_opp_freq

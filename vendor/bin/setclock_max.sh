#!/system/bin/sh

# Performance mode: all clocks pinned to maximum

A76_MAX=$(cat /sys/devices/system/cpu/cpu6/cpufreq/cpuinfo_max_freq)
A55_MAX=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
GPU_MAX=$(cat /proc/gpufreq/gpufreq_opp_dump 2>/dev/null | head -1 | sed 's/.*freq = \([0-9]*\).*/\1/')

# EEM voltage offsets
echo 10 > /proc/eem/EEM_DET_B/eem_offset
echo 0 > /proc/eem/EEM_DET_L/eem_offset

# Disable all PPM policies
for i in 0 1 2 3 4 5 6 7 8 9; do
    echo "$i 0" > /proc/ppm/policy_status 2>/dev/null
done
echo "-1 -1" > /proc/ppm/policy/ut_fix_freq_idx

# Reset PPM hard limits to max
echo "0 $A55_MAX" > /proc/ppm/policy/hard_userlimit_max_cpu_freq
echo "1 $A76_MAX" > /proc/ppm/policy/hard_userlimit_max_cpu_freq

# CPU governors: performance
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo performance > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor

# Pin to max
echo $A55_MAX > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo $A76_MAX > /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq
echo $A55_MAX > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo $A76_MAX > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq

# GPU: fix to max
echo $GPU_MAX > /proc/gpufreq/gpufreq_opp_freq

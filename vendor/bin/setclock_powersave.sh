#!/system/bin/sh

# Power save mode: capped clocks for battery life

# EEM voltage offsets
echo 10 > /proc/eem/EEM_DET_B/eem_offset
echo 0 > /proc/eem/EEM_DET_L/eem_offset

# Re-enable all PPM policies
for i in 0 1 2 3 4 5 6 7 8 9; do
    echo "$i 1" > /proc/ppm/policy_status 2>/dev/null
done
echo "-1 -1" > /proc/ppm/policy/ut_fix_freq_idx

# CPU governors: schedutil
echo schedutil > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo schedutil > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor

# Cap frequencies via PPM hard user limits
echo "0 1500000" > /proc/ppm/policy/hard_userlimit_max_cpu_freq
echo "1 1530000" > /proc/ppm/policy/hard_userlimit_max_cpu_freq

# GPU: cap to low OPP
echo 620000 > /proc/gpufreq/gpufreq_opp_freq

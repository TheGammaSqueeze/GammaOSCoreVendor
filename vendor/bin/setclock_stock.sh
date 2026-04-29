#!/system/bin/sh

# Balanced mode: dynamic scaling up to max available OPP

A76_MAX=$(cat /sys/devices/system/cpu/cpu6/cpufreq/cpuinfo_max_freq)
A55_MAX=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)

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

# Reset PPM hard limits to max (undo powersave caps)
echo "0 $A55_MAX" > /proc/ppm/policy/hard_userlimit_max_cpu_freq
echo "1 $A76_MAX" > /proc/ppm/policy/hard_userlimit_max_cpu_freq

# GPU: dynamic scaling
echo 0 > /proc/gpufreq/gpufreq_opp_freq

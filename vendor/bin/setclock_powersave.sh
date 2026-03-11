#!/system/bin/sh

# CPU governor: powersave for both clusters
echo powersave > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo powersave > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor

# CPU lock to minimum frequencies
echo 500000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 500000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 774000 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq
echo 774000 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_max_freq

# PPM: fix both clusters to index 15 (min freq)
echo "15 15" > /proc/ppm/policy/ut_fix_freq_idx

# GPU: fix to min OPP (270 MHz)
echo 270000 > /proc/gpufreq/gpufreq_opp_freq

#!/system/bin/sh

echo 33 > /sys/kernel/ged/hal/custom_boost_gpu_freq

echo -1 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp

echo 0 > /proc/gpufreq/gpufreq_opp_freq

echo -1 -1 -1 > /proc/ppm/policy/ut_fix_freq_idx

#echo 0 0 0 > /proc/ppm/policy/retro_min_cpu_freq

echo "0" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo "2000000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

echo "500000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
echo "2600000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor

echo "437000" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
echo "2600000" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq
echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor

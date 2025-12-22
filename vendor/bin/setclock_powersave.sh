#!/system/bin/sh

# GPU (Mali) DevFreq Tuning
echo powersave > /sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali/governor
echo 265000000 > /sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali/min_freq
echo 1400000000 > /sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali/max_freq
echo -1 > /proc/gpufreqv2/fix_target_opp_index
echo 42 > /sys/devices/platform/soc/1c00f000.dvfsrc/1c00f000.dvfsrc:dvfsrc-helper/dvfsrc_force_vcore_dvfs_opp

# DVFSRC (System DVFS) DevFreq Tuning
echo powersave > /sys/devices/platform/soc/1c00f000.dvfsrc/mtk-dvfsrc-devfreq/devfreq/mtk-dvfsrc-devfreq/governor
echo 800000000 > /sys/devices/platform/soc/1c00f000.dvfsrc/mtk-dvfsrc-devfreq/devfreq/mtk-dvfsrc-devfreq/min_freq
echo 6400000000 > /sys/devices/platform/soc/1c00f000.dvfsrc/mtk-dvfsrc-devfreq/devfreq/mtk-dvfsrc-devfreq/max_freq

# UFS Host Controller DevFreq
echo powersave > /sys/devices/platform/soc/112b0000.ufshci/devfreq/112b0000.ufshci/governor
echo 273000000 > /sys/devices/platform/soc/112b0000.ufshci/devfreq/112b0000.ufshci/min_freq
echo 458333313 > /sys/devices/platform/soc/112b0000.ufshci/devfreq/112b0000.ufshci/max_freq

# CPU Frequency Scaling

# LITTLE cluster (policy0)
echo schedutil > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 480000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo 2200000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo 0 > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed
echo -1 > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed

# MID cluster (policy4)
echo powersave > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
echo 400000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
echo 3200000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
echo 0 > /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed
echo -1 > /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed

# BIG cluster (policy7)
echo powersave > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor
echo 400000 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
echo 3350000 > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq
echo 0 > /sys/devices/system/cpu/cpufreq/policy7/scaling_setspeed
echo -1 > /sys/devices/system/cpu/cpufreq/policy7/scaling_setspeed

# Kernel Scheduling and Timer Tweaks
#echo 1 > /proc/sys/kernel/timer_migration
#echo 0 > /proc/sys/kernel/sched_energy_aware

# cpuset Configuration
#echo 4-7 > /dev/cpuset/top-app/cpus
#echo 1 > /dev/cpuset/top-app/cpu_exclusive
#echo 0 > /dev/cpuset/top-app/sched_load_balance
#echo 0 > /dev/cpuset/top-app/sched_relax_domain_level
#echo 0 > /dev/cpuset/sched_load_balance

#echo "All performance tweaks and swap setup applied."

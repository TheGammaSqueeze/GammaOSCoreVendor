#!/system/bin/sh
# max_performance.sh – lock GPU, CPU & memory to absolute max

# 1) GPU → pick highest OPP from the gpufreq table and boost to it
max_gpu_freq=836000
echo "$max_gpu_freq" > /proc/gpufreq/gpufreq_opp_freq
echo "$max_gpu_freq" > /sys/kernel/ged/hal/custom_boost_gpu_freq

# 2) VCORE/DRAM rail → force highest voltage/freq OPP (index 0)
echo 0 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp

# 3) CPU clusters → fix both LITTLE & big domains at top OPP (0)
echo 0 0 0 > /proc/ppm/policy/ut_fix_freq_idx

# 4) Prevent CPU from ever dropping below OPP 0
# echo 0 0 0 > /proc/ppm/policy/retro_min_cpu_freq

# 5) For good measure, also pin the cpufreq governors to “performance” at max-freq
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  freqs=$(cat $policy/scaling_available_frequencies)
  # highest is last in the space-separated list
  max_freq=$(echo $freqs | awk '{print $NF}')

  # lock min & max to the peak
  echo $max_freq > $policy/scaling_min_freq
  echo $max_freq > $policy/scaling_max_freq

  # switch to performance governor if available
  if grep -qw performance $policy/scaling_available_governors; then
    echo performance > $policy/scaling_governor
  else
    echo schedutil    > $policy/scaling_governor
  fi
done

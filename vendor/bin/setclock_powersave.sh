#!/system/bin/sh

echo 0 > /sys/kernel/ged/hal/custom_boost_gpu_freq

echo -1 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp

echo 0 > /proc/gpufreq/gpufreq_opp_freq

echo -1 -1 -1 > /proc/ppm/policy/ut_fix_freq_idx

#echo 0 0 0 > /proc/ppm/policy/retro_min_cpu_freq

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  # find lowest frequency in the list
  freqs=$(cat $policy/scaling_available_frequencies)
  lowest=$(echo $freqs | awk '{print $1}')

  # push min & max to the lowest so even a dynamic governor can't climb
  echo $lowest > $policy/scaling_min_freq
  echo $lowest > $policy/scaling_max_freq

  # switch to powersave if supported, else fallback to schedutil
  govs=$(cat $policy/scaling_available_governors)
  if echo "$govs" | grep -qw powersave; then
    echo powersave > $policy/scaling_governor
  else
    echo schedutil  > $policy/scaling_governor
  fi
done

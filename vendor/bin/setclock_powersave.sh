#!/system/bin/sh

sleep 1

echo 32 > /sys/kernel/ged/hal/custom_boost_gpu_freq

echo -1 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp

echo 350000 > /proc/gpufreq/gpufreq_opp_freq

echo 15 15 15 > /proc/ppm/policy/ut_fix_freq_idx

echo 15 15 15 > /proc/ppm/policy/retro_min_cpu_freq

echo "500000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo "500000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo "powersave" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

echo "437000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
echo "437000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
echo "powersave" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor

echo "659000" > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
echo "659000" > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq
echo "powersave" > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor

# === now dump out min/max/current freqs ===
echo
echo "=== FREQUENCY STATUS ==="

# CPU clusters
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  name=$(basename $policy)
  minf=$(cat $policy/scaling_min_freq)
  maxf=$(cat $policy/scaling_max_freq)
  curf=$(cat $policy/scaling_cur_freq)
  echo "$name  min: ${minf} kHz | max: ${maxf} kHz | cur: ${curf} kHz"
done

# GPU
echo
echo "GPU "
gb=$(cat /sys/kernel/ged/hal/custom_boost_gpu_freq)
go=$(cat /proc/gpufreq/gpufreq_opp_freq)
# try to find the devfreq-exposed cur_freq
gpu_dev=$(ls /sys/class/devfreq | grep -i mali | head -n1)
if [ -n "$gpu_dev" ]; then
  gcur=$(cat /sys/class/devfreq/$gpu_dev/cur_freq)
else
  gcur="N/A"
fi
echo "  custom_boost: ${gb} kHz"
echo "  fixed_opp:    ${go} kHz"
echo "  current:      ${gcur} kHz"

# VCORE/DRAM (DVFSRC)
echo
echo "VCORE/DRAM (DVFSRC) "
vforce=$(cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp)
# try to read current OPP; if not present, show N/A
vcur=$(
  cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_cur_opp 2>/dev/null \
    || echo "N/A"
)
echo "  forced_opp: ${vforce}"
echo "  current_opp: ${vcur}"

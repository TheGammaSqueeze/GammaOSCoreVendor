#!/system/bin/sh

sleep 1

echo "320000000" > /sys/devices/platform/soc/5900000.qcom,kgsl-3d0/devfreq/5900000.qcom,kgsl-3d0/min_freq
echo "465000000" > /sys/devices/platform/soc/5900000.qcom,kgsl-3d0/devfreq/5900000.qcom,kgsl-3d0/max_freq
echo "msm-adreno-tz" > /sys/devices/platform/soc/5900000.qcom,kgsl-3d0/devfreq/5900000.qcom,kgsl-3d0/governor

echo "300000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo "1056000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo "walt" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

echo "300000" > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
echo "652800" > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
echo "walt" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor

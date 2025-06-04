#!/system/bin/sh

echo "340000000" > /sys/devices/platform/soc/3d00000.qcom,kgsl-3d0/devfreq/3d00000.qcom,kgsl-3d0/min_freq
echo "1010000000" > /sys/devices/platform/soc/3d00000.qcom,kgsl-3d0/devfreq/3d00000.qcom,kgsl-3d0/max_freq
echo "msm-adreno-tz" > /sys/devices/platform/soc/3d00000.qcom,kgsl-3d0/devfreq/3d00000.qcom,kgsl-3d0/governor
echo "200" > /sys/devices/platform/soc/3d00000.qcom,kgsl-3d0/devfreq/3d00000.qcom,kgsl-3d0/polling_interval

echo "672000" > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo "1958400" > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo "walt" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor

echo "691200" > /sys/devices/system/cpu/cpufreq/policy6/scaling_min_freq
echo "2400000" > /sys/devices/system/cpu/cpufreq/policy6/scaling_max_freq
echo "walt" > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
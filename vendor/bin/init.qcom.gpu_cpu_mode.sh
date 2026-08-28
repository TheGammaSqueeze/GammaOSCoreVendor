#! /vendor/bin/sh
#
# CPU/GPU mode control
# persist.sys.cpu.mode / persist.vendor.cpu.mode:
#   0 - 省电模式
#   1 - 正常模式
#   2 - 性能模式
#   3 - 高性能模式

export PATH=/vendor/bin

INIT_PATH="/sys/class/thermal"

if [ -n "$1" ]; then
	PARAM="$1"
else
	PARAM=`getprop persist.vendor.cpu.mode`
fi

case "$PARAM" in
	0|1|2|3)
		;;
	*)
		echo "Invalid cpu mode '$PARAM', expected 0-3"
		exit 1
		;;
esac

case $PARAM in
	0)
		echo "Applying powersave mode..."
		echo 499200 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
		echo 499200 > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
		echo 691200 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq
		echo 6 > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
		echo 0 > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
		echo 340000000 > /sys/class/kgsl/kgsl-3d0/devfreq/min_freq
		echo 1010000000 > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq
		echo powersave > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
		echo powersave > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
		echo "enabled" > $INIT_PATH/thermal_zone16/mode
		echo "enabled" > $INIT_PATH/thermal_zone17/mode
		echo "enabled" > $INIT_PATH/thermal_zone18/mode
		echo "enabled" > $INIT_PATH/thermal_zone19/mode
		echo "enabled" > $INIT_PATH/thermal_zone20/mode
		echo "enabled" > $INIT_PATH/thermal_zone21/mode
		echo "enabled" > $INIT_PATH/thermal_zone22/mode
		echo "enabled" > $INIT_PATH/thermal_zone23/mode
		echo "enabled" > $INIT_PATH/thermal_zone24/mode
		echo "enabled" > $INIT_PATH/thermal_zone25/mode
		echo "enabled" > $INIT_PATH/thermal_zone26/mode
		echo "enabled" > $INIT_PATH/thermal_zone27/mode
		echo "enabled" > $INIT_PATH/thermal_zone28/mode
		echo "enabled" > $INIT_PATH/thermal_zone45/mode
		;;
	1)
		echo "Applying normal mode..."
		echo 499200 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
		echo 499200 > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
		echo 691200 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq
		echo 6 > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
		echo 0 > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
		echo 340000000 > /sys/class/kgsl/kgsl-3d0/devfreq/min_freq
		echo 1010000000 > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq
		echo walt > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
		echo walt > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
		echo "enabled" > $INIT_PATH/thermal_zone16/mode
		echo "enabled" > $INIT_PATH/thermal_zone17/mode
		echo "enabled" > $INIT_PATH/thermal_zone18/mode
		echo "enabled" > $INIT_PATH/thermal_zone19/mode
		echo "enabled" > $INIT_PATH/thermal_zone20/mode
		echo "enabled" > $INIT_PATH/thermal_zone21/mode
		echo "enabled" > $INIT_PATH/thermal_zone22/mode
		echo "enabled" > $INIT_PATH/thermal_zone23/mode
		echo "enabled" > $INIT_PATH/thermal_zone24/mode
		echo "enabled" > $INIT_PATH/thermal_zone25/mode
		echo "enabled" > $INIT_PATH/thermal_zone26/mode
		echo "enabled" > $INIT_PATH/thermal_zone27/mode
		echo "enabled" > $INIT_PATH/thermal_zone28/mode
		echo "enabled" > $INIT_PATH/thermal_zone45/mode
		;;
	2)
		echo "Applying performance mode..."
		echo 1286400 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
		echo 1286400 > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
		echo 1497600 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq
		echo 3 > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
		echo 0 > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
		echo 765000000 > /sys/class/kgsl/kgsl-3d0/devfreq/min_freq
		echo 1010000000 > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq
		echo walt > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
		echo walt > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
		echo "disabled" > $INIT_PATH/thermal_zone16/mode
		echo "disabled" > $INIT_PATH/thermal_zone17/mode
		echo "disabled" > $INIT_PATH/thermal_zone18/mode
		echo "disabled" > $INIT_PATH/thermal_zone19/mode
		echo "disabled" > $INIT_PATH/thermal_zone20/mode
		echo "disabled" > $INIT_PATH/thermal_zone21/mode
		echo "disabled" > $INIT_PATH/thermal_zone22/mode
		echo "disabled" > $INIT_PATH/thermal_zone23/mode
		echo "disabled" > $INIT_PATH/thermal_zone24/mode
		echo "disabled" > $INIT_PATH/thermal_zone25/mode
		echo "disabled" > $INIT_PATH/thermal_zone26/mode
		echo "disabled" > $INIT_PATH/thermal_zone27/mode
		echo "disabled" > $INIT_PATH/thermal_zone28/mode
		echo "disabled" > $INIT_PATH/thermal_zone45/mode
		;;
	3)
		echo "Applying high performance mode..."
		echo 1958400 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
		echo 1958400 > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
		echo 2400000 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq
		echo 0 > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
		echo 0 > /sys/class/kgsl/kgsl-3d0/max_pwrlevel
		echo 1010000000 > /sys/class/kgsl/kgsl-3d0/devfreq/min_freq
		echo 1010000000 > /sys/class/kgsl/kgsl-3d0/devfreq/max_freq
		echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
		echo performance > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
		echo "disabled" > $INIT_PATH/thermal_zone16/mode
		echo "disabled" > $INIT_PATH/thermal_zone17/mode
		echo "disabled" > $INIT_PATH/thermal_zone18/mode
		echo "disabled" > $INIT_PATH/thermal_zone19/mode
		echo "disabled" > $INIT_PATH/thermal_zone20/mode
		echo "disabled" > $INIT_PATH/thermal_zone21/mode
		echo "disabled" > $INIT_PATH/thermal_zone22/mode
		echo "disabled" > $INIT_PATH/thermal_zone23/mode
		echo "disabled" > $INIT_PATH/thermal_zone24/mode
		echo "disabled" > $INIT_PATH/thermal_zone25/mode
		echo "disabled" > $INIT_PATH/thermal_zone26/mode
		echo "disabled" > $INIT_PATH/thermal_zone27/mode
		echo "disabled" > $INIT_PATH/thermal_zone28/mode
		echo "disabled" > $INIT_PATH/thermal_zone45/mode
		;;
esac

echo "CPU/GPU mode configuration completed: $PARAM"

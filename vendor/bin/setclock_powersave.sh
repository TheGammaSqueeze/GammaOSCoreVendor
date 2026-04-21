#!/system/bin/sh
# Power-saving profile. Loops settings for at least 30 seconds so the
# state cannot be drifted by other subsystems during that window. No
# non-OC/OC phase since this profile has no OC setpoints.

GPU=/sys/devices/platform/27800000.gpu/devfreq/27800000.gpu
GPU_DEV=/sys/devices/platform/27800000.gpu
VOP=/sys/devices/platform/27d00000.vop/devfreq/27d00000.vop
DMC=/sys/devices/platform/dmc/devfreq/dmc
P0=/sys/devices/system/cpu/cpufreq/policy0
P4=/sys/devices/system/cpu/cpufreq/policy4

apply() {
  echo powersave > $GPU/governor
  echo 300000000 > $GPU/min_freq
  echo 300000000 > $GPU/max_freq
  # Restore default power policy so the GPU power-gates when idle.
  # setclock_max/stock pin always_on; this mode reverses that.
  echo coarse_demand > $GPU_DEV/power_policy

  echo powersave > $VOP/governor
  echo 500000000 > $VOP/min_freq
  echo 500000000 > $VOP/max_freq

  echo powersave > $DMC/governor
  echo 528000000 > $DMC/min_freq
  echo 528000000 > $DMC/max_freq

  echo schedutil > $P0/scaling_governor
  echo 408000 > $P0/scaling_min_freq
  echo 816000 > $P0/scaling_max_freq

  echo schedutil > $P4/scaling_governor
  echo 408000 > $P4/scaling_min_freq
  echo 816000 > $P4/scaling_max_freq
}

end=$(($(date +%s) + 30))
while [ $(date +%s) -lt $end ]; do
  apply
  sleep 1
done

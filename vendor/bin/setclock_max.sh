#!/system/bin/sh
# Max performance profile. Verified against the device via adb, this
# SKU's OPP tables cap at GPU 800 MHz, little-CPU 1920 MHz, big-CPU
# 2112 MHz (DMC 2112, VOP 702). "Max" pins every rail to its highest
# available OPP; there is no OC headroom above the stock table and no
# GPU stuck-at-1000 state on this SKU (no 1000 OPP exists).
#
# Write order: write min to its lowest target first, then max to the
# new ceiling, then raise min to the pin target. This is robust across
# all starting states (powersave-left, PowerAIDL-set, already-pinned)
# without any min>max kernel rejections.

GPU=/sys/devices/platform/27800000.gpu/devfreq/27800000.gpu
GPU_DEV=/sys/devices/platform/27800000.gpu
VOP=/sys/devices/platform/27d00000.vop/devfreq/27d00000.vop
DMC=/sys/devices/platform/dmc/devfreq/dmc
P0=/sys/devices/system/cpu/cpufreq/policy0
P4=/sys/devices/system/cpu/cpufreq/policy4

apply_non_oc() {
  echo performance > $GPU/governor
  # Pin the GPU to its 800 MHz ceiling: min=300 (lowest OPP, always
  # valid), then max=800, then min=800 pins the top OPP.
  echo 300000000 > $GPU/min_freq
  echo 800000000 > $GPU/max_freq
  echo 800000000 > $GPU/min_freq

  echo performance > $VOP/governor
  echo 500000000 > $VOP/min_freq
  echo 702000000 > $VOP/max_freq
  echo 702000000 > $VOP/min_freq

  echo performance > $DMC/governor
  echo 528000000  > $DMC/min_freq
  echo 2112000000 > $DMC/max_freq
  echo 2112000000 > $DMC/min_freq

  echo performance > $P0/scaling_governor
  echo 408000  > $P0/scaling_min_freq
  echo 1920000 > $P0/scaling_max_freq
  echo 1920000 > $P0/scaling_min_freq

  echo performance > $P4/scaling_governor
  echo 408000  > $P4/scaling_min_freq
  echo 2112000 > $P4/scaling_max_freq
  echo 2112000 > $P4/scaling_min_freq
}

apply_oc() {
  # GPU already at its 800 MHz ceiling (no OC OPP above stock).
  echo 800000000 > $GPU/max_freq
  echo 800000000 > $GPU/min_freq

  echo 702000000 > $VOP/max_freq
  echo 702000000 > $VOP/min_freq

  echo 2112000000 > $DMC/max_freq
  echo 2112000000 > $DMC/min_freq

  echo 1920000 > $P0/scaling_max_freq
  echo 1920000 > $P0/scaling_min_freq

  echo 2112000 > $P4/scaling_max_freq
  echo 2112000 > $P4/scaling_min_freq
}

apply_non_oc
apply_oc

# Keep the GPU PLL hot in the max profile (always_on) for consistent
# peak performance; the stock/powersave profiles restore coarse_demand
# so the GPU power-gates when idle.
echo always_on > $GPU_DEV/power_policy

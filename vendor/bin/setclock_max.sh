#!/system/bin/sh
# Full OC max profile. apply_non_oc sets all rails to pre-OC ceilings
# and walks the GPU down to 900 MHz through the 900 OPP visit (unstick
# setup, see rk3576_gpu_stuck_state). apply_oc raises the GPU to 1000
# MHz (the 900->1000 return completes the unstick bounce) and lifts
# CPU/DMC/VOP to OC ceilings.
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
  # Walk to 900 MHz visiting the 900 OPP. min=300 is the lowest OPP
  # and always valid; then max=900 forces a transition to 900 (down
  # from 1000, or up from 300), and min=900 pins.
  echo 300000000 > $GPU/min_freq
  echo 900000000 > $GPU/max_freq
  echo 900000000 > $GPU/min_freq

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
  echo 2016000 > $P0/scaling_max_freq
  echo 2016000 > $P0/scaling_min_freq

  echo performance > $P4/scaling_governor
  echo 408000  > $P4/scaling_min_freq
  echo 2208000 > $P4/scaling_max_freq
  echo 2208000 > $P4/scaling_min_freq
}

apply_oc() {
  # GPU 900->1000 return completes the unstick bounce.
  echo 1000000000 > $GPU/max_freq
  echo 1000000000 > $GPU/min_freq

  echo 702000000 > $VOP/max_freq
  echo 702000000 > $VOP/min_freq

  echo 2112000000 > $DMC/max_freq
  echo 2112000000 > $DMC/min_freq

  echo 2208000 > $P0/scaling_max_freq
  echo 2208000 > $P0/scaling_min_freq

  echo 2304000 > $P4/scaling_max_freq
  echo 2304000 > $P4/scaling_min_freq
}

apply_non_oc
apply_oc

# Pin the Mali power policy to always_on. Default coarse_demand
# power-gates the GPU when idle; on resume the PLL re-initialises into
# a stuck "half-speed" state (see rk3576_gpu_stuck_state) that the
# bounce above already performed won't catch because by then the user
# has likely left the initial active window. always_on keeps the PLL
# hot so the bounce's unstick persists into the first vita3k session.
echo always_on > $GPU_DEV/power_policy

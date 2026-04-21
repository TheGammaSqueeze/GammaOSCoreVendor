#!/system/bin/sh
# Stock (dynamic) profile. apply_non_oc walks the GPU to 900 MHz
# through the 900 OPP visit (unstick setup, see rk3576_gpu_stuck_state)
# under performance governor, then sets CPU/DMC/VOP to non-OC dynamic
# governors. apply_oc completes the GPU 900->1000 unstick return (still
# under performance), then hands the GPU off to simple_ondemand and
# raises CPU/DMC/VOP ceilings for OC dynamic scaling.
#
# Write order: min-low, max-target, min-target. Robust across starting
# states without min>max kernel rejections.

GPU=/sys/devices/platform/27800000.gpu/devfreq/27800000.gpu
GPU_DEV=/sys/devices/platform/27800000.gpu
VOP=/sys/devices/platform/27d00000.vop/devfreq/27d00000.vop
DMC=/sys/devices/platform/dmc/devfreq/dmc
P0=/sys/devices/system/cpu/cpufreq/policy0
P4=/sys/devices/system/cpu/cpufreq/policy4

apply_non_oc() {
  # Bounce is done under performance so freq tracks max_freq writes.
  echo performance > $GPU/governor
  echo 300000000 > $GPU/min_freq
  echo 900000000 > $GPU/max_freq
  echo 900000000 > $GPU/min_freq

  echo vop2_ondemand > $VOP/governor
  echo 500000000 > $VOP/min_freq
  echo 702000000 > $VOP/max_freq

  echo dmc_ondemand > $DMC/governor
  echo 528000000  > $DMC/min_freq
  echo 2112000000 > $DMC/max_freq

  echo schedutil > $P0/scaling_governor
  echo 408000  > $P0/scaling_min_freq
  echo 2016000 > $P0/scaling_max_freq

  echo schedutil > $P4/scaling_governor
  echo 408000  > $P4/scaling_min_freq
  echo 2208000 > $P4/scaling_max_freq
}

apply_oc() {
  # Complete the GPU 900->1000 return under performance, then hand off
  # to simple_ondemand with OC range (700-1000).
  echo 1000000000 > $GPU/max_freq
  echo 1000000000 > $GPU/min_freq
  echo simple_ondemand > $GPU/governor
  echo 700000000  > $GPU/min_freq
  echo 1000000000 > $GPU/max_freq

  echo 702000000 > $VOP/max_freq

  echo 2112000000 > $DMC/max_freq

  echo 2208000 > $P0/scaling_max_freq

  echo 2304000 > $P4/scaling_max_freq
}

apply_non_oc
apply_oc

# Keep Mali PLL powered (see setclock_max.sh for rationale). Stock mode
# is still an active-use profile, so the small power cost is worth
# preventing the stuck-on-resume state.
echo always_on > $GPU_DEV/power_policy

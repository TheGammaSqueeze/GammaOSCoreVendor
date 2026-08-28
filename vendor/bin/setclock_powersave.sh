#!/system/bin/sh
# Power-saving profile for the RG 55G1 (SM4450 / Adreno 613). Caps the
# GPU to its lowest OPP and both CPU clusters to a low ceiling. Loops
# for ~30 seconds so framework services that keep rewriting governors
# right after a screen-off cannot drift the state during that window.

GPU=/sys/class/kgsl/kgsl-3d0/devfreq
P0=/sys/devices/system/cpu/cpufreq/policy0
P6=/sys/devices/system/cpu/cpufreq/policy6

apply() {
  # GPU: pin 340 MHz (lowest OPP)
  echo powersave  > $GPU/governor
  echo 340000000  > $GPU/min_freq
  echo 340000000  > $GPU/max_freq

  # CPU cluster 0 (little): cap at 806.4 MHz
  echo walt   > $P0/scaling_governor
  echo 499200 > $P0/scaling_min_freq
  echo 806400 > $P0/scaling_max_freq

  # CPU cluster 1 (big): cap at 960 MHz
  echo walt   > $P6/scaling_governor
  echo 691200 > $P6/scaling_min_freq
  echo 960000 > $P6/scaling_max_freq
}

end=$(($(date +%s) + 30))
while [ $(date +%s) -lt $end ]; do
  apply
  sleep 1
done

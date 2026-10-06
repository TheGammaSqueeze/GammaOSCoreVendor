#!/vendor/bin/sh
# RP Duo Lite nano mode clock policy. The walt governor parks the little cores at
# 614 MHz and the Adreno sits at 320 to 465 MHz under the DRM home, which drives
# two panels (1080x1920 + 1280x960) every frame: the PS3 XMB measured 46 to 55 fps
# with 33 ms frames. With the CPUs on the performance governor and the GPU held
# at its top level it holds 60.0 fps (max frame 17.5 ms). Applied for the nano
# home and drastic-nano sessions (sys.gammaos.minimal_boot=1), re-applied after
# boot_completed because the home re-asserts the stock clocks then.
apply() {
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -f "$p/scaling_governor" ] && echo performance > "$p/scaling_governor"
    done
    echo 0 > /sys/class/kgsl/kgsl-3d0/min_pwrlevel
}
apply
# The home applies the stock clocks ~1 s after boot_completed; apply again after that.
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 120 ]; do sleep 1; i=$((i+1)); done
sleep 4
apply
exit 0

#!/vendor/bin/sh
# Reboot once after the WL818S bridge firmware is flashed.
#
# A boot that performs a bridge flash cannot bring the bottom DP panel up on that
# same boot: the flash re-powers the bridge over the already-live DP link and the
# SoC DP encoder is left erroring, with no clean re-bring-up. The very next boot,
# where the MCU date now matches the firmware so no flash runs, brings the panel
# up clean. This oneshot detects a successful flash this boot and reboots once.
#
# It never loops: a successful flash makes the next boot skip the upgrade, so no
# SUCCESS line appears and no reboot happens. A failed/wedged flash (no valid
# readback) does not reboot either - that is left for the Volume-Up stock path.
#
# Works in Nano (DRM-direct) and Android: it is plain init + shell and reads only
# the kernel log. (GammaOS runs SELinux permissive; if that ever changes this
# needs a syslog_read grant for its domain.)

TAG=wl818_postflash
klog() { echo "$TAG: $*" > /dev/kmsg 2>/dev/null; }

# Wait for this boot's fw_check to finish (DP powers on ~7 s; a flash adds ~10 s).
i=0
while [ $i -lt 45 ]; do
    if dmesg 2>/dev/null | grep -q 'sec-bl-uart: fw_check: complete'; then
        break
    fi
    sleep 1
    i=$((i + 1))
done

# Reboot only when a flash actually succeeded this boot.
if dmesg 2>/dev/null | grep -q 'sec-bl-uart: fw_upgrade: SUCCESS' \
   && dmesg 2>/dev/null | grep -qE 'sec-bl-uart: fw_check: MCU date readback after upgrade=[0-9]{8}'; then
    klog "bridge firmware flashed this boot; rebooting once for a clean DP bring-up"
    sync
    setprop sys.powerctl reboot
else
    klog "no bridge flash this boot (or flash did not confirm); nothing to do"
fi

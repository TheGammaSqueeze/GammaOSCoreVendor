#!/vendor/bin/sh
# Workaround for a USB configfs gadget-teardown regression on this kernel build:
# during an adb -> mtp,adb switch the stale ffs.adb symlink in configs/b.1/f1 is
# not removed in time, so mtp.gs0 never links and the host sees no MTP function.
# Re-assert the mtp,adb layout after unbinding the UDC (with a short settle) so the
# rm succeeds. No-op if the gadget is already correct (unaffected kernels).
G=/config/usb_gadget/g1
C=$G/configs/b.1
if [ "$(basename "$(readlink $C/f1 2>/dev/null)" 2>/dev/null)" = "mtp.gs0" ]; then
    exit 0
fi
echo none > $G/UDC 2>/dev/null
sleep 0.3
rm -f $C/f1 2>/dev/null
rm -f $C/f2 2>/dev/null
ln -s $G/functions/mtp.gs0 $C/f1 2>/dev/null
ln -s $G/functions/ffs.adb $C/f2 2>/dev/null
echo 5100000.udc-controller > $G/UDC 2>/dev/null

#!/vendor/bin/sh
# On config=none the kernel's UDC unbind is async, so the GSI's rm of the gadget
# function links races and fails, leaving a stale ffs.adb in b.1/f1 that blocks the
# next mtp config. Retry the rm while we are still in the none phase so the next
# config binds a correct gadget on the first try (no post-hoc re-enumeration).
C=/config/usb_gadget/g1/configs/b.1
i=0
while [ "$(getprop sys.usb.config)" = "none" ] && [ $i -lt 25 ]; do
    rm -f $C/f1 $C/f2 $C/f3 2>/dev/null
    [ -e $C/f1 ] || break
    sleep 0.02
    i=$((i+1))
done

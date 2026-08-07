#!/vendor/bin/sh
# Re-assert the MTP gadget layout to work around a USB configfs teardown race on
# this kernel: config=none does not clear the stale ffs.adb link in b.1/f1 before
# the mtp[,adb] config relinks, so mtp.gs0 never links and the host sees no MTP.
# Must run FAST (no startup delay) to win the race before the framework reverts to
# adb. Handles both "mtp" and "mtp,adb"; no-op once the layout is already correct.
G=/config/usb_gadget/g1
C=$G/configs/b.1
case "$(getprop sys.usb.config)" in mtp) m=1;; mtp,adb) m=2;; *) exit 0;; esac
f1=$(readlink $C/f1 2>/dev/null); f1=${f1##*/}
if [ "$f1" = "mtp.gs0" ]; then
    [ "$m" = 1 ] && exit 0
    f2=$(readlink $C/f2 2>/dev/null); f2=${f2##*/}
    [ "$f2" = "ffs.adb" ] && exit 0
fi
echo none > $G/UDC 2>/dev/null
rm -f $C/f1 $C/f2 2>/dev/null
ln -s $G/functions/mtp.gs0 $C/f1 2>/dev/null
[ "$m" = 2 ] && ln -s $G/functions/ffs.adb $C/f2 2>/dev/null
echo 5100000.udc-controller > $G/UDC 2>/dev/null

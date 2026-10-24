#!/vendor/bin/sh
# GammaOS: keep a copy of the kernel log (init and vold log there too) and of logcat on
# /metadata while the boot is in progress, so a boot that dies before adb or /data (for
# example init sending the device to recovery with "init_user0_failed", or vold waiting
# forever for keystore2) can still be read afterwards: /metadata is mounted by first stage
# init and recovery can mount it. Both files are rewritten every 2 s until sys.boot_completed,
# then once more, each copy synced so a hard reset keeps it; the previous boot's copies are
# kept as .prev.
D=/metadata/gammaos
F=$D/boot_dmesg.txt
L=$D/boot_logcat.txt
mkdir -p $D 2>/dev/null || exit 0
[ -f $F ] && mv -f $F $F.prev
[ -f $L ] && mv -f $L $L.prev
snap() {
    dmesg > $F.tmp 2>/dev/null && mv -f $F.tmp $F
    /system/bin/logcat -d -b main -b system -b crash -v threadtime > $L.tmp 2>/dev/null && mv -f $L.tmp $L
    sync
}
i=0
while [ $i -lt 600 ]; do
    snap
    [ "$(getprop sys.boot_completed)" = "1" ] && break
    sleep 2
    i=$((i + 1))
done
snap

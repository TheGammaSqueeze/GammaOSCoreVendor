#!/vendor/bin/sh
# GammaOS: keep a copy of the kernel log (init and vold log there too) on /metadata while the
# boot is in progress, so a boot that dies before adb or /data (for example init sending the
# device to recovery with "init_user0_failed") can still be read afterwards: /metadata is
# mounted by first stage init and recovery can mount it. One file, rewritten every 2 s until
# sys.boot_completed, then once more; the previous boot's copy is kept as .prev.
D=/metadata/gammaos
F=$D/boot_dmesg.txt
mkdir -p $D 2>/dev/null || exit 0
[ -f $F ] && mv -f $F $F.prev
i=0
while [ $i -lt 600 ]; do
    dmesg > $F.tmp 2>/dev/null && mv -f $F.tmp $F
    [ "$(getprop sys.boot_completed)" = "1" ] && break
    sleep 2
    i=$((i + 1))
done
dmesg > $F.tmp 2>/dev/null && mv -f $F.tmp $F

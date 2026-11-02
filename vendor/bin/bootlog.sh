#!/vendor/bin/sh
# GammaOS: keep a boot log on the raw logdump partition while the boot is in
# progress, so a boot that never reaches adb (USB never enumerates, system_server
# stuck on the boot animation) can still be read afterwards from recovery:
#   adb shell sh -c 'P=$(readlink -f /dev/block/by-name/logdump); \
#       n=$(head -c 64 $P | head -1 | cut -d" " -f3); head -c $((64 + n)) $P | tail -c $n'
# (the previous boot's copy sits at offset 256 MiB, same layout).
#
# Layout at each copy: a 64-byte header line "GAMMAOS_BOOTLOG v1 <bytes>" padded
# with spaces, then <bytes> of text: uptime, USB/gadget state, props, processes,
# the kernel log and logcat. The snapshot is assembled in /dev (tmpfs) and written
# with dd conv=fsync every 3 s until LOG_UNTIL seconds of uptime. Nano mode sets
# sys.boot_completed about 10 s in, so stopping there missed everything after. Not
# /metadata: it is ~10 MiB and holds vold's keys, a full logcat could fill it.
#
# A boot that has not completed after REBOOT_AFTER seconds of uptime is sent to
# recovery (root adb there) once its final snapshot is written. Creating
# /metadata/gammaos/bootlog_noreboot (from recovery adb) keeps it logging instead.
REBOOT_AFTER=180
LOG_UNTIL=300
NOREBOOT=/metadata/gammaos/bootlog_noreboot

P=$(readlink -f /dev/block/by-name/logdump 2>/dev/null)
[ -b "$P" ] || P=$(readlink -f /dev/block/bootdevice/by-name/logdump 2>/dev/null)
[ -b "$P" ] || { echo "bootlog: no logdump partition" > /dev/kmsg; exit 0; }

T=/dev/gammaos_bootlog
H=$T.hdr
B=$T.body
PREV=65536   # 4 KiB blocks: 256 MiB

# previous boot's log -> offset 256 MiB (only if a valid header is there)
hdr=$(head -c 64 "$P" 2>/dev/null | head -1)
case "$hdr" in
    "GAMMAOS_BOOTLOG v1 "*)
        n=$(echo "$hdr" | cut -d' ' -f3)
        dd if="$P" of="$P" bs=4096 count=$(((64 + n + 4095) / 4096)) seek=$PREV conv=notrunc,fsync 2>/dev/null
        ;;
esac

section() { echo; echo "===== $* ====="; }

snap() {
    {
        section "uptime $(cut -d' ' -f1 /proc/uptime) s"
        echo "selinux: $(cat /sys/fs/selinux/enforce 2>/dev/null) slot: $(getprop ro.boot.slot_suffix)"

        section "usb"
        echo "udc: $(ls /sys/class/udc 2>/dev/null)"
        echo "g1/UDC: $(cat /config/usb_gadget/g1/UDC 2>/dev/null)"
        echo "g1 idVendor/idProduct: $(cat /config/usb_gadget/g1/idVendor 2>/dev/null) $(cat /config/usb_gadget/g1/idProduct 2>/dev/null)"
        ls -l /config/usb_gadget/g1/configs/b.1 2>&1
        ls /config/usb_gadget/g1/functions 2>&1
        grep -E ' (/config|/dev/usb-ffs/adb) ' /proc/mounts
        for d in /sys/class/typec/port*; do
            [ -d "$d" ] && echo "$d data_role=$(cat $d/data_role 2>/dev/null) power_role=$(cat $d/power_role 2>/dev/null)"
        done
        for d in /sys/class/usb_role/*; do
            [ -d "$d" ] && echo "$d role=$(cat $d/role 2>/dev/null)"
        done
        for f in /sys/bus/platform/devices/*.ssusb/mode /sys/bus/platform/devices/*.dwc3/mode; do
            [ -f "$f" ] && echo "$f=$(cat $f 2>/dev/null)"
        done

        section "props"
        getprop

        section "processes"
        ps -A -o PID,PPID,USER,STAT,NAME 2>/dev/null || ps -A

        section "dmesg"
        dmesg

        section "logcat"
        /system/bin/logcat -d -b all -v threadtime 2>&1
    } > $B 2>&1
    n=$(stat -c %s $B)
    printf '%-63s\n' "GAMMAOS_BOOTLOG v1 $n" > $H
    cat $H $B | dd of="$P" bs=4096 conv=notrunc,fsync 2>/dev/null
}

echo "bootlog: writing to $P" > /dev/kmsg
up() { cut -d. -f1 /proc/uptime; }

i=0
while [ $i -lt 400 ]; do
    snap
    [ "$(up)" -ge $LOG_UNTIL ] && break
    if [ "$(getprop sys.boot_completed)" != "1" ] && [ "$(up)" -ge $REBOOT_AFTER ] && [ ! -e $NOREBOOT ]; then
        echo "bootlog: boot not completed after $(up) s, rebooting to recovery" > /dev/kmsg
        snap
        rm -f $H $B
        setprop sys.powerctl reboot,recovery
        exit 0
    fi
    sleep 3
    i=$((i + 1))
done
snap
rm -f $H $B

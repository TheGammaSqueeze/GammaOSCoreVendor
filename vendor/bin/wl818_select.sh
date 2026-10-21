#!/vendor/bin/sh
# Select which WL818S bridge firmware the kernel flashes on this boot.
#
# Default: /vendor/firmware/wl818s_fw.bin (our custom match60 build, good timings).
# Backup : /vendor/firmware/wl818s_fw_stock.bin (stock 20260917 from the QFIL).
#
# The sec_bl_uart module always requests the basename "wl818s_fw.bin" and searches
# firmware_class.path first. To flash the stock backup we point firmware_class.path
# at a writable directory that holds the stock image under that basename. The
# choice is persisted in /mnt/vendor/persist/wl818/use_stock (survives factory
# reset and /data), so once a user switches to stock it stays on stock until they
# switch back. This runs at post-fs, before the DP powers on and fw_check reads the
# firmware.
#
# Volume-Up at boot toggles the flag (handled by the key read that calls this with
# "toggle"); without an argument it just applies the persisted choice.

TAG=wl818_select
DIR=/mnt/vendor/persist/wl818
FLAG=$DIR/use_stock
ACTIVE=$DIR/active
FCP=/sys/module/firmware_class/parameters/path
STOCK=/vendor/firmware/wl818s_fw_stock.bin
klog() { echo "$TAG: $*" > /dev/kmsg 2>/dev/null; }

mkdir -p "$DIR" 2>/dev/null

# Volume-Up held at boot toggles the choice (stock <-> custom). The helper reads
# the live key state (EVIOCGKEY), so a press that is still held when this runs is
# caught. "$1" = toggle forces a toggle for testing without the key.
if [ "$1" = "toggle" ] || /vendor/bin/wl818_volup; then
    if [ "$(cat $FLAG 2>/dev/null)" = "1" ]; then
        echo 0 > "$FLAG"
        klog "Volume-Up: switching back to the custom firmware"
    else
        echo 1 > "$FLAG"
        klog "Volume-Up: switching to the stock firmware"
    fi
    sync
fi

if [ "$(cat $FLAG 2>/dev/null)" = "1" ]; then
    if [ -r "$STOCK" ]; then
        mkdir -p "$ACTIVE" 2>/dev/null
        cp "$STOCK" "$ACTIVE/wl818s_fw.bin" 2>/dev/null
        echo "$ACTIVE" > "$FCP"
        klog "stock bridge firmware selected (firmware_class.path=$ACTIVE)"
    else
        klog "stock backup missing ($STOCK); staying on default firmware"
    fi
else
    klog "default (custom) bridge firmware selected (firmware_class.path=$(cat $FCP 2>/dev/null))"
fi

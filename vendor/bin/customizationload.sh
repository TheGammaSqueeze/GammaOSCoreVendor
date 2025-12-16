#!/system/bin/sh

# File-backed Swap Allocation
 [ ! -f /mnt/pass_through/0/emulated/swap ] && \
   dd if=/dev/zero of=/mnt/pass_through/0/emulated/swap bs=10M count=1200 && \
   mkswap /mnt/pass_through/0/emulated/swap
 swapon /mnt/pass_through/0/emulated/swap -p 1

# zram-based Swap (4 GiB Fixed)
swapoff /dev/block/zram0 2>/dev/null
 echo 1 > /sys/block/zram0/reset
 echo 4294967296 > /sys/block/zram0/disksize
 mkswap /dev/block/zram0
 swapon /dev/block/zram0 -p 5

cat /proc/swaps
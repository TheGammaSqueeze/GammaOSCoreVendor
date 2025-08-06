#!/vendor/bin/sh

echo 1 | tee /sys/fs/f2fs/dm-*/discard_granularity >/dev/null
echo 0 | tee /sys/fs/f2fs/dm-*/discard_idle_interval >/dev/null
echo 1 | tee /sys/fs/f2fs/dm-*/gc_urgent > /dev/null

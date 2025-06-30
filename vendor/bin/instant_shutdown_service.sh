#!/system/bin/sh

# Enable SysRq if not already
echo 1 >/proc/sys/kernel/sysrq

# Wait for the real powerctl value
while true; do
  cmd=$(getprop sys.powerctl)
  case "$cmd" in
    shutdown*|reboot*) break ;;
  esac
  sleep 0.1
done

# Timestamp for debugging
ts=$(date '+%Y-%m-%d %H:%M:%S')
echo "$ts triggered $cmd" >> /sdcard/powerctl.log 2>/dev/null
echo "$ts triggered $cmd" >> /data/powerctl.log 2>/dev/null

# Flush user and kernel buffers
sync
echo s >/proc/sysrq-trigger
sync
echo s >/proc/sysrq-trigger

# Give it a moment, then do the final o/b
sleep 3
case "$cmd" in
  shutdown*) echo o >/proc/sysrq-trigger ;;
  reboot*)   echo b >/proc/sysrq-trigger ;;
esac

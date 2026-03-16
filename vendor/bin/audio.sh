#!/system/bin/sh

# Restart playback forever. If stagefright exits with an error, pause briefly
# to avoid a tight respawn loop.
while true; do
  stagefright -a -o /vendor/etc/silent.mp3 || sleep 1
done

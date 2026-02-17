#!/vendor/bin/sh
if ! applypatch --check EMMC:/dev/block/by-name/recovery$(getprop ro.boot.slot_suffix):94902272:a00f014786928371c368b1521cf4de0cd597055e; then
  applypatch  \
          --patch /vendor/recovery-from-boot.p \
          --source EMMC:/dev/block/by-name/boot$(getprop ro.boot.slot_suffix):53946368:bf65f0531797b0b7f788763081aef807c31adc4d \
          --target EMMC:/dev/block/by-name/recovery$(getprop ro.boot.slot_suffix):94902272:a00f014786928371c368b1521cf4de0cd597055e && \
      log -t recovery "Installing new recovery image: succeeded" || \
      log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi

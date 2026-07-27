#!/usr/bin/env bash
# Build vendor.img (ext4) + vendor.img.erofs (lz4hc) for MagicX XU20 (A133P).
set -euo pipefail
if [ "$EUID" -ne 0 ]; then echo "run as root"; exit 1; fi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE"
rm -f vendor.img
MKE2FS_CONFIG=mke2fs.conf ./mke2fs -O ^has_journal,^sparse_super -L vendor -M /vendor -m 0 -t ext4 -b 4096 vendor.img 54253
./e2fsdroid -e -T 1230768000 -S selinux_contexts.txt -f vendor/ -a / vendor.img
UUID="$(blkid -s UUID -o value vendor.img 2>/dev/null || echo e73f3ebb-dcc1-43cc-9386-bb5757f49f45)"
MNT="$(mktemp -d)"; LOOP="$(losetup -f --show -r vendor.img)"
trap 'set +e; umount "$MNT" 2>/dev/null; losetup -d "$LOOP" 2>/dev/null; rmdir "$MNT" 2>/dev/null' EXIT
mount -t ext4 -o ro "$LOOP" "$MNT"
rm -f vendor.img.erofs
( cd "$MNT" && mkfs.erofs -zlz4hc -C 65536 -T 1230768000 -x 16 -U "$UUID" "$HERE/vendor.img.erofs" . )
umount "$MNT"; losetup -d "$LOOP"; rmdir "$MNT"; trap - EXIT
echo "=== built ==="; ls -lh vendor.img vendor.img.erofs

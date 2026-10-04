#!/bin/bash
# Build the Duo Lite (trinket / SM6125) vendor image: ext4 via mke2fs+e2fsdroid,
# then convert to EROFS. e2fsdroid is the single source of truth for filesystem
# metadata (uid/gid, modes, capabilities, SELinux xattrs), so the vendor/ tree
# must be read with its original ownership intact. The extracted tree is
# root-owned with restricted directories (e.g. vendor/bin is 0751), so the whole
# build runs as root. Re-exec under sudo if we are not already root.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

cd "$(dirname "$0")"

# --- Recreate empty directories git cannot track -------------------------------
# git does not store empty directories. These vendor dirs contain no files or
# symlinks in their subtree, so a fresh checkout is missing them and e2fsdroid
# would omit mountpoints the platform expects. Recreate them before building.
# (Regenerate this list with:
#    for d in $(find vendor -type d|sort); do \
#      [ -z "$(find "$d" -mindepth 1 ! -type d -print -quit)" ] && echo "$d"; done )
mkdir -p vendor/bt_firmware
mkdir -p vendor/dsp
mkdir -p vendor/firmware_mnt
mkdir -p vendor/lost+found

# --- Size the ext4 image from the actual tree ---------------------------------
# The ext4 image is only an intermediate (EROFS is the shipped artifact), so it
# is sized generously: content + 30% + 64 MiB headroom, with inodes for every
# entry plus margin. This adapts to any vendor tree instead of a fixed count.
VENDOR_BYTES=$(du -s --block-size=1 vendor | awk '{print $1}')
ENTRIES=$(find vendor | wc -l)
DATA_BLOCKS=$(( (VENDOR_BYTES + 4095) / 4096 ))
IMG_BLOCKS=$(( DATA_BLOCKS + DATA_BLOCKS * 30 / 100 + 16384 ))
INODES=$(( ENTRIES + ENTRIES / 4 + 1024 ))
echo "=== vendor tree: ${VENDOR_BYTES} bytes, ${ENTRIES} entries ==="
echo "=== ext4 image: ${IMG_BLOCKS} x 4096-byte blocks, ${INODES} inodes ==="

rm -f vendor.img
MKE2FS_CONFIG=mke2fs.conf ./mke2fs -O ^has_journal,^sparse_super -L vendor -M /vendor \
    -m 0 -t ext4 -b 4096 -N "$INODES" vendor.img "$IMG_BLOCKS"
# fs_config.txt restores uid/gid/mode/caps that git cannot store (see fs_config.sh);
# without it every file would default to root:root and all file capabilities
# (bluetooth, gps, cnd, sensors, wifi) would be lost.
if [ ! -f fs_config.txt ]; then
    echo "ERROR: fs_config.txt missing; run ./fs_config.sh against an ownership-intact tree" >&2
    exit 1
fi
./e2fsdroid -e -T 1230768000 -C fs_config.txt -S selinux_contexts.txt -f vendor/ -a / vendor.img

# --- Convert ext4 -> EROFS (lz4hc big-pcluster, feature 0x3) -------------------
# Mount the e2fsdroid-built ext4 image read-only and build EROFS from the mount,
# so every uid/gid, capability and SELinux xattr carries over byte-for-byte.
# Needs root for losetup+mount+mkfs.erofs (we are already root here). Verified
# with lz4hc (kernel 5.15 big_pcluster, no lzma). Flash vendor.img.erofs to
# /vendor via fastbootd.
UUID="$(blkid -o value -s UUID vendor.img)"
EROFS_OUT="$(pwd)/vendor.img.erofs"
MNT="$(mktemp -d -t erofs_vendor.XXXX)"
LOOP="$(losetup -f --show -r vendor.img)"
_erofs_cleanup() { umount "$MNT" 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap _erofs_cleanup EXIT
mount -t ext4 -o ro "$LOOP" "$MNT"
rm -f "$EROFS_OUT"
( cd "$MNT" && mkfs.erofs -zlz4hc -C 65536 -T 1230768000 -x 16 -U "$UUID" "$EROFS_OUT" . )
_erofs_cleanup; trap - EXIT

# Hand the build artifacts back to the invoking user, not root.
REAL_USER="${SUDO_USER:-root}"
chown "$REAL_USER":"$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")" \
    vendor.img vendor.img.erofs 2>/dev/null || true

echo "=== built vendor.img + vendor.img.erofs ==="
ls -lh vendor.img vendor.img.erofs
sha256sum vendor.img vendor.img.erofs

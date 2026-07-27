#!/usr/bin/env bash
# Build vendor.img (ext4) and vendor.img.erofs (lz4hc-compressed, read-only)
# for TrimUI zero40 (Allwinner A133P, SD-card storage).
#
# The EROFS image is decompressed at runtime by the in-tree erofs.ko module
# (vendor/modules/erofs.ko, vermagic 4.9.170 - identical kernel to the Brick,
# so the module is shared). lz4hc keeps decompression cost at plain-LZ4 level
# while shrinking the image, which cuts real I/O time on the slow SD bus.
#
# Run with sudo (mount + mkfs.erofs need root).
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "error: this script needs root (mount + mkfs.erofs)" >&2
    echo "       run as: sudo bash $0" >&2
    exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

# --- Step 1: ext4 vendor.img (e2fsdroid is the source of truth for perms/uid/gid/selinux) ---
rm -f vendor.img
MKE2FS_CONFIG=mke2fs.conf ./mke2fs -O ^has_journal,^sparse_super -L vendor -M /vendor -m 0 -t ext4 -b 4096 vendor.img 43000
./e2fsdroid -e -T 1230768000 -S selinux_contexts.txt -f vendor/ -a / vendor.img

# --- Step 2: convert ext4 -> EROFS from a read-only loop mount so all metadata
#     (perms, uid/gid, security.selinux xattrs) is inherited byte-for-byte ---
UUID="$(blkid -s UUID -o value vendor.img 2>/dev/null || true)"
UUID="${UUID:-e73f3ebb-dcc1-43cc-9386-bb5757f49f45}"

MNT="$(mktemp -d -t erofs_vendor.XXXX)"
LOOP="$(losetup -f --show -r vendor.img)"
trap '
    set +e
    umount "$MNT" 2>/dev/null
    losetup -d "$LOOP" 2>/dev/null
    rmdir "$MNT" 2>/dev/null
' EXIT

mount -t ext4 -o ro "$LOOP" "$MNT"

rm -f vendor.img.erofs
( cd "$MNT" && mkfs.erofs \
    -zlz4hc \
    -C 65536 \
    -T 1230768000 \
    -x 16 \
    -U "$UUID" \
    "$HERE/vendor.img.erofs" \
    . )

umount "$MNT"; losetup -d "$LOOP"; rmdir "$MNT"; trap - EXIT

echo
echo "=== built vendor.img + vendor.img.erofs ==="
ls -lh vendor.img vendor.img.erofs
sha256sum vendor.img vendor.img.erofs

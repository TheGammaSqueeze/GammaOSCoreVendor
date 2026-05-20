#!/usr/bin/env bash
# Build vendor.img (ext4) and vendor.img.erofs (lz4hc-compressed read-only)
# for TrimUI Brick (Allwinner A133, slow SD card storage).
#
# Parameters match the golden vendor image: UUID, hash seed,
# block/inode counts for ext4. The erofs build uses lz4hc + legacy
# fixed-output compression, which the in-tree EROFS module
# (vendor/modules/erofs.ko) decompresses with the embedded post-4.11
# LZ4 lib. lz4hc is the right choice for the SD card on this device:
# decompression cost is the same as LZ4, the smaller image means less
# I/O against the bottleneck (~22 MB/s SD HS bus).
#
# Run with sudo - this script chowns the source tree to root:root and
# uses setfattr to apply SELinux contexts, both of which need root.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "error: this script needs root (chown + setfattr)" >&2
    echo "       run as: sudo bash $0" >&2
    exit 1
fi

# Step 1. Restore the canonical permissions+ownership+selinux state
# on the vendor source tree. This makes the build reproducible from a
# fresh git checkout (where xattrs would be missing and ownership
# would be the cloning user's uid).
chown -R root:root vendor/
bash apply_contexts.sh vendor/ selinux_contexts.txt

# Step 2. Build ext4 image (the canonical image with correct perms,
# ownership, and SELinux xattrs applied by e2fsdroid).
rm -f vendor.img

MKE2FS_CONFIG=mke2fs.conf ./mke2fs \
    -O 'sparse_super,resize_inode,^has_journal' \
    -L vendor \
    -M /vendor \
    -U e73f3ebb-dcc1-43cc-9386-bb5757f49f45 \
    -E 'hash_seed=b3f11505-219e-4a51-9eb7-c870540d3109' \
    -m 0 \
    -t ext4 \
    -b 4096 \
    -I 256 \
    -N 2048 \
    vendor.img 45000

./e2fsdroid \
    -e \
    -T 1230768000 \
    -S selinux_contexts.txt \
    -f vendor/ \
    -a / \
    vendor.img

# Step 3. Convert ext4 to EROFS by mounting the ext4 image and building
# EROFS from the mount. This guarantees the EROFS image is byte-for-byte
# identical in permissions, uid/gid, and SELinux xattrs to the ext4 image
# (e2fsdroid is the single source of truth for all filesystem metadata).
UUID="e73f3ebb-dcc1-43cc-9386-bb5757f49f45"
MNT="$(mktemp -d -t erofs_vendor.XXXX)"
LOOP="$(losetup -f --show -r vendor.img)"
trap '
    set +e
    umount "$MNT" 2>/dev/null
    losetup -d "$LOOP" 2>/dev/null
    rmdir "$MNT" 2>/dev/null
' EXIT

mount -t ext4 -o ro "$LOOP" "$MNT"

EROFS_OUT="$(pwd)/vendor.img.erofs"
rm -f "$EROFS_OUT"
( cd "$MNT" && mkfs.erofs \
    -zlz4hc \
    -C 65536 \
    -T 1230768000 \
    -x 16 \
    -U "$UUID" \
    "$EROFS_OUT" \
    . )

umount "$MNT"
losetup -d "$LOOP"
rmdir "$MNT"
trap - EXIT

echo
echo "=== built vendor.img + vendor.img.erofs ==="
ls -lh vendor.img vendor.img.erofs
sha256sum vendor.img vendor.img.erofs

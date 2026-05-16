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

# Step 2. Build ext4 image (used as the fallback in fstab).
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

# Step 3. Build erofs image. xattrs and ownership are already applied
# to the source tree by step 1, so mkfs.erofs picks them up directly.
# Same approach as the 405v / 405m / 505 vendor builds.
#
# Flags:
#  -zlz4hc            best compression for SD-card-bound boot reads
#  -E legacy-compress fixed-output-size clusters (compatible with the
#                     in-tree EROFS module's decompressor)
#  -T 1230768000      fixed UNIX epoch for deterministic mtimes
#  -x 16              inline xattrs up to 16 bytes (matches 405v)
#  -U <uuid>          match the ext4 image so flashing either side
#                     does not confuse fstab consumers that read UUID
rm -f vendor.img.erofs
(
    cd vendor
    mkfs.erofs \
        -zlz4hc \
        -E legacy-compress \
        -T 1230768000 \
        -x 16 \
        -U e73f3ebb-dcc1-43cc-9386-bb5757f49f45 \
        ../vendor.img.erofs \
        .
)

echo
echo "=== built vendor.img + vendor.img.erofs ==="
ls -lh vendor.img vendor.img.erofs
sha256sum vendor.img vendor.img.erofs

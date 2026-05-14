#!/usr/bin/env bash
# Build vendor.img for TrimUI Brick (Allwinner A133, ext4, no journal).
# Parameters match the golden vendor image: UUID, hash seed, block/inode counts.
set -euo pipefail

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

echo
echo "=== built vendor.img ==="
ls -lh vendor.img
sha256sum vendor.img

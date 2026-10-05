#!/bin/bash
# Build the Duo Lite (trinket / SM6125) vendor image as ext4 (vendor.img) using
# mke2fs + e2fsdroid. e2fsdroid is the single source of truth for filesystem
# metadata: SELinux labels come from selinux_contexts.txt and ownership/mode/
# capabilities from fs_config.txt, because git stores none of those. Flash
# vendor.img to /vendor via fastbootd.
#
# The extracted tree is root-owned with restricted directories (e.g. vendor/bin
# is 0751), so the build runs as root; it re-execs under sudo if needed.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

cd "$(dirname "$0")"

# --- Recreate every directory git cannot guarantee ----------------------------
# git restores a directory only when it still contains a tracked file, so empty
# directories (and any whose contents are all git-dropped) vanish on a fresh
# clone. vendor_dirs.txt is the complete, committed list of vendor directories;
# recreate them all here so none is ever missing, whatever the checkout state.
# Regenerate vendor_dirs.txt with ./fs_config.sh (it writes it alongside
# fs_config.txt from the authoritative source tree).
if [ ! -f vendor_dirs.txt ]; then
    echo "ERROR: vendor_dirs.txt missing; run ./fs_config.sh against the source tree" >&2
    exit 1
fi
while IFS= read -r d; do
    [ -n "$d" ] && mkdir -p "vendor/$d"
done < vendor_dirs.txt
# lost+found is a reserved inode mke2fs owns; e2fsdroid keeps the source mode
# for it rather than the fs_config mode, so set it to match the device (0700).
chmod 700 vendor/lost+found 2>/dev/null || true

# --- Size the ext4 image from the actual tree ---------------------------------
# Sized generously: content + 30% + 64 MiB headroom, inodes for every entry
# plus margin. This adapts to any vendor tree instead of a fixed count.
VENDOR_BYTES=$(du -s --block-size=1 vendor | awk '{print $1}')
ENTRIES=$(find vendor | wc -l)
DATA_BLOCKS=$(( (VENDOR_BYTES + 4095) / 4096 ))
IMG_BLOCKS=$(( DATA_BLOCKS + DATA_BLOCKS * 30 / 100 + 16384 ))
INODES=$(( ENTRIES + ENTRIES / 4 + 1024 ))
echo "=== vendor tree: ${VENDOR_BYTES} bytes, ${ENTRIES} entries ==="
echo "=== ext4 image: ${IMG_BLOCKS} x 4096-byte blocks, ${INODES} inodes ==="

if [ ! -f fs_config.txt ]; then
    echo "ERROR: fs_config.txt missing; run ./fs_config.sh against an ownership-intact tree" >&2
    exit 1
fi
if [ ! -f selinux_contexts.txt ]; then
    echo "ERROR: selinux_contexts.txt missing; run ./selinux.sh against an ownership-intact tree" >&2
    exit 1
fi

rm -f vendor.img
MKE2FS_CONFIG=mke2fs.conf ./mke2fs -O ^has_journal,^sparse_super -L vendor -M /vendor \
    -m 0 -t ext4 -b 4096 -N "$INODES" vendor.img "$IMG_BLOCKS"
# -C fs_config.txt restores uid/gid/mode/caps; -S selinux_contexts.txt the labels.
./e2fsdroid -e -T 1230768000 -C fs_config.txt -S selinux_contexts.txt -f vendor/ -a / vendor.img

# Hand the artifact back to the invoking user, not root.
REAL_USER="${SUDO_USER:-root}"
chown "$REAL_USER":"$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")" vendor.img 2>/dev/null || true

echo "=== built vendor.img (ext4) ==="
ls -lh vendor.img
sha256sum vendor.img

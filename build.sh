rm -f vendor.img
MKE2FS_CONFIG=mke2fs.conf ./mke2fs -O ^has_journal,^sparse_super -L vendor -M /vendor -m 0 -t ext4 -b 4096 vendor.img 78052
./e2fsdroid -e -T 1230768000 -S selinux_contexts.txt -f vendor/ -a / vendor.img

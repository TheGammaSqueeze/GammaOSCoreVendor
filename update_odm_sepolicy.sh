#!/bin/bash
# Rebuild odm_image/odm.img with a precompiled SELinux policy that matches the system image
# currently booted on the Duo Lite (adb), so first-stage init loads the policy instead of
# compiling it (2.1 s at every boot when the hashes differ).
#
# The odm partition holds only /etc/selinux/precompiled_sepolicy and its three hash files.
# init uses it only when plat/system_ext/product *_sepolicy_and_mapping.sha256 on the device
# match the copies stored next to it, so rerun this after any system build that changes the
# platform policy (init falls back to compiling, safely, until then).
# Usage: ./update_odm_sepolicy.sh [adb serial]   then flash odm_image/odm.img (fastbootd: flash odm)
set -euo pipefail
cd "$(dirname "$0")"
SER="${1:-ece7025b}"
ADB="/usr/bin/adb -s $SER"
V=$($ADB shell cat /vendor/etc/selinux/plat_sepolicy_vers.txt | tr -d '\r')
$ADB shell "cd /data/local/tmp && rm -rf sepol_out && mkdir sepol_out && args='' &&
  for f in /system/etc/selinux/mapping/$V.compat.cil /system_ext/etc/selinux/system_ext_sepolicy.cil \
           /system_ext/etc/selinux/mapping/$V.cil /system_ext/etc/selinux/mapping/$V.compat.cil \
           /product/etc/selinux/product_sepolicy.cil /product/etc/selinux/mapping/$V.cil \
           /vendor/etc/selinux/plat_pub_versioned.cil /vendor/etc/selinux/vendor_sepolicy.cil \
           /odm/etc/selinux/odm_sepolicy.cil; do [ -e \$f ] && args=\"\$args \$f\"; done &&
  secilc /system/etc/selinux/plat_sepolicy.cil -m -M true -G -N -c 30 /system/etc/selinux/mapping/$V.cil \
         -o sepol_out/precompiled_sepolicy -f /dev/null \$args &&
  cp /system/etc/selinux/plat_sepolicy_and_mapping.sha256 sepol_out/precompiled_sepolicy.plat_sepolicy_and_mapping.sha256 &&
  cp /system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256 sepol_out/precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256 &&
  cp /product/etc/selinux/product_sepolicy_and_mapping.sha256 sepol_out/precompiled_sepolicy.product_sepolicy_and_mapping.sha256"
W=$(mktemp -d); mkdir -p $W/root/etc/selinux $W/root/lost+found
for f in precompiled_sepolicy precompiled_sepolicy.plat_sepolicy_and_mapping.sha256 \
         precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256 precompiled_sepolicy.product_sepolicy_and_mapping.sha256; do
  $ADB pull /data/local/tmp/sepol_out/$f $W/root/etc/selinux/$f >/dev/null
done
rm -f odm_image/odm.img
./mke2fs -t ext4 -b 4096 -I 256 -N 32 -L odm -U 78e9a000-a7b8-58c3-b4bd-96acf73df2b9 \
  -O ^has_journal,^metadata_csum -E root_owner=0:0 odm_image/odm.img 346 >/dev/null
./e2fsdroid -e -T 1230768000 -C odm_image/odm_fs_config -S odm_image/odm_file_contexts -f $W/root -a / odm_image/odm.img
rm -rf $W
echo "odm_image/odm.img rebuilt for policy $V"

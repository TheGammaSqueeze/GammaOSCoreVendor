rm -f vendor.img

# Create empty directories that exist in the original image but not in git
mkdir -p \
  vendor/bin/crossbuild/DataSet/SQLiteModule/db/{ae,af,awb,awbsync,feature,flash,flashcali,pd,pipeline,tone}/mt6983 \
  vendor/bin/crossbuild/DataSet/SQLiteModule/db/mt6983 \
  vendor/bin/crossbuild/DataSet/SQLiteModule/db/tuning_DB/{default_sensor,gc5035_mipi_raw,hi1339_mipi_raw,hi1339subofilm_mipi_raw,hi1339subtxd_mipi_raw,imx214_mipi_raw,imx334_mipi_raw,imx334sub_mipi_raw,imx481_mipi_raw,imx499_mipi_raw,imx586_mipi_raw,imx709o_mipi_raw,imx766_mipi_raw,imx766dual_mipi_raw,imx766dualo_mipi_raw,imx766o_mipi_raw,ov13b10lz_mipi_raw,ov16b10ff_mipi_raw,ov48b_mipi_raw,s5k3l6wide_mipi_raw,s5k3m5sx_mipi_raw,s5k3m5sxo_mipi_raw,s5k3p9sp_mipi_raw,s5k5e9yx_mipi_raw,s5kgd2sp_mipi_raw,s5kgnvsp_mipi_raw,s5kjn1tele_mipi_raw}/mt6983 \
  vendor/bin/crossbuild/DataSet/SQLiteModule/db/tuning_DB/mt6983 \
  vendor/bin/hw/mt6983 \
  vendor/bin/mt6983 \
  vendor/lib/egl/mt6983 \
  vendor/lib/hw/mt6983 \
  vendor/lib/mt6983 \
  vendor/lib64/egl/mt6983 \
  vendor/lib64/hw/mt6983 \
  vendor/lib64/mt6983

MKE2FS_CONFIG=mke2fs.conf ./mke2fs -O ^has_journal -N 4096 -L vendor -M /vendor -m 0 -t ext4 -b 4096 vendor.img 230905
./e2fsdroid -e -T 1230768000 -C fs_config.txt -S selinux_contexts.txt -f vendor/ -a / vendor.img
DIR="$(cd "$(dirname "$0")" && pwd)"
PATH="$DIR:$PATH" LD_LIBRARY_PATH="$DIR:$LD_LIBRARY_PATH" python3 avbtool.py add_hashtree_footer --image vendor.img --partition_name vendor --partition_size 961040384 --hash_algorithm sha256 --algorithm NONE

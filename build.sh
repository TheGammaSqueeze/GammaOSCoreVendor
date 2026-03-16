rm -rf vendor.img
cd vendor
mkfs.erofs -d9 -zlz4hc -E legacy-compress -U eb0b9428-848d-528a-91bf-7a639e0fbe71 -T 1230768000 -x 16 ../vendor.img .
cd ..
chmod 777 vendor.img

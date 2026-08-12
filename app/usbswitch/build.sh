#!/bin/bash
set -e
cd "$(dirname "$0")"
SDK=/home/gamma/Android/Sdk
BT=$SDK/build-tools/34.0.0
AJAR=$SDK/platforms/android-34/android.jar
KEYDIR=/work/GammaOSNextDistribution-A14/build/make/target/product/security
rm -rf out; mkdir -p out/classes out/gen
echo "[1/6] aapt2 compile resources (strings + 14 locales, icon, banner)"
$BT/aapt2 compile --dir res -o out/res.zip
echo "[2/6] aapt2 link (manifest + resources)"
$BT/aapt2 link out/res.zip --manifest AndroidManifest.xml -I "$AJAR" \
    --min-sdk-version 30 --target-sdk-version 34 \
    --java out/gen -o out/base.apk
echo "[3/6] javac"
javac --release 11 -classpath "$AJAR" -d out/classes \
    $(find src out/gen -name '*.java') 2>&1 | grep -v "warning:" || true
echo "[4/6] d8 -> dex"
/work/GammaOSNextDistribution-A14/out/host/linux-x86/bin/d8 --min-api 30 --output out $(find out/classes -name '*.class')
echo "[5/6] add classes.dex to apk + align"
cp out/base.apk out/unaligned.apk
( cd out && zip -qj unaligned.apk classes.dex )
$BT/zipalign -f 4 out/unaligned.apk out/UsbSwitch.apk
echo "[6/6] sign with platform key"
$BT/apksigner sign --key "$KEYDIR/platform.pk8" --cert "$KEYDIR/platform.x509.pem" out/UsbSwitch.apk
$BT/apksigner verify -v out/UsbSwitch.apk | head -5
ls -l out/UsbSwitch.apk

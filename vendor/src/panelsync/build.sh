#!/bin/bash
# Builds panelsync for the vendor image (installs to ../../bin/panelsync).
T=/work/GammaOSNextDistribution-A14
cd "$(dirname "$0")"
$T/prebuilts/clang/host/linux-x86/clang-r510928/bin/clang --target=aarch64-linux-android29 \
  --sysroot=$T/out/soong/ndk/sysroot -B$T/out/soong/.intermediates/bionic/libc/crtbegin_dynamic/android_arm64_armv8-a_apex10000 -B$T/out/soong/.intermediates/bionic/libc/crtend_android/android_arm64_armv8-a_apex10000 \
  -O2 -Wall -fPIE -pie -s -o /tmp/panelsync.$$ panelsync.c -lm && install -m 0755 /tmp/panelsync.$$ ../../bin/panelsync && rm -f /tmp/panelsync.$$

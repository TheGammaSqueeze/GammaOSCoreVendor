#!/bin/sh
# Builds retroidpad for aarch64 bionic with the AOSP prebuilt clang + NDK sysroot.
T=/work/GammaOSNextDistribution-A14
cd "$(dirname "$0")"
$T/prebuilts/clang/host/linux-x86/clang-r510928/bin/clang --target=aarch64-linux-android29 \
  --sysroot=$T/out/soong/ndk/sysroot -B$T/out/soong/.intermediates/bionic/libc/crtbegin_dynamic/android_arm64_armv8-a_apex10000 -B$T/out/soong/.intermediates/bionic/libc/crtend_android/android_arm64_armv8-a_apex10000 \
  -O2 -Wall -fPIE -pie -s -o retroidpad RetroidPad.c

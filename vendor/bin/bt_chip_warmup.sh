#!/system/bin/sh
# Pre-warm the xradio Bluetooth chip at boot.
# libbt-vendor's BluetoothHci::initialize() does its own rfkill cycle plus
# a ~2s settle wait, which pushes total HAL init past the Android 14 GD
# stack's 3s timeout. By cycling rfkill here at boot, the chip is already
# powered and stable when the framework opens it; the second cycle inside
# libbt-vendor still happens but completes much faster on a warm chip.
echo 0 > /sys/class/rfkill/rfkill0/state
sleep 1
echo 1 > /sys/class/rfkill/rfkill0/state
sleep 2
echo 1 > /proc/bluetooth/sleep/lpm
echo 1 > /proc/bluetooth/sleep/btwake
echo 1 > /proc/bluetooth/sleep/btwrite

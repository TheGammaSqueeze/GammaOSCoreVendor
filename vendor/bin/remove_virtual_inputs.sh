#!/system/bin/sh
#
# Remove boot-time virtual input devices (virtual_gamepad, gsensor) 30s
# after boot. These interfere with real input handling once the user
# starts interacting with the device.
#
# Historical note: this script used to also loop `wm size 640x480` as a
# boot-time workaround for a display metrics race. That loop has been
# removed because it races GammaOS DualStack, which explicitly forces
# the default display to 640x960 when a DualStack app is in foreground.
# The old `wm size 640x480` line would reset DualStacks forced-tall
# override and break the split-screen mirror until the next traversal.

sleep 30;

for name in virtual_gamepad gsensor; do ev=$(grep -A5 "Name=\"$name\"" /proc/bus/input/devices | grep 'Handlers' | head -n 1); ev=${ev#*Handlers=}; ev=${ev%% *}; [ -n "$ev" ] && rm -f "/dev/input/$ev"; done

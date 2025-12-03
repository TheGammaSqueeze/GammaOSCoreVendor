#!/system/bin/sh

sleep 30;

for name in virtual_gamepad gsensor; do ev=$(grep -A5 "Name=\"$name\"" /proc/bus/input/devices | grep 'Handlers' | head -n 1); ev=${ev#*Handlers=}; ev=${ev%% *}; [ -n "$ev" ] && rm -f "/dev/input/$ev"; done

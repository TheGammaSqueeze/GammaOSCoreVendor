#!/system/bin/sh
#
# disable_touch_joypad.sh
#
# Find any input event node whose name is "touch_joypad"
# via /sys/class/input and remove or disable its /dev/input entry.

TARGET_NAME="touch_joypad"

log() {
    echo "[disable_touch_joypad] $*" >&2
}

# Iterate over all event devices exposed via sysfs
for name_path in /sys/class/input/event*/device/name; do
    [ -f "$name_path" ] || continue

    dev_name="$(cat "$name_path" 2>/dev/null || echo "")"
    if [ "$dev_name" != "$TARGET_NAME" ]; then
        continue
    fi

    # name_path:   /sys/class/input/event3/device/name
    # dev_dir:     /sys/class/input/event3/device
    # event_dir:   /sys/class/input/event3
    # event_node:  event3
    dev_dir="$(dirname "$name_path")"
    event_dir="$(dirname "$dev_dir")"
    event_node="$(basename "$event_dir")"
    dev_node="/dev/input/$event_node"

    log "Found $TARGET_NAME at $event_node (sysfs: $event_dir)"

    if [ -e "$dev_node" ]; then
        # First try to remove the node
        if rm -f "$dev_node" 2>/dev/null; then
            log "Removed device node $dev_node"
        else
            # If removal fails, lock it down by permissions instead
            if chmod 000 "$dev_node" 2>/dev/null; then
                log "Could not remove $dev_node, permissions set to 000"
            else
                log "Failed to remove or chmod $dev_node, check permissions or SELinux"
            fi
        fi
    else
        log "Device node $dev_node does not exist"
    fi
done

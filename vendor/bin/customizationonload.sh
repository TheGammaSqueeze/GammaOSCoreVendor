#!/system/bin/sh

# Check migration flag
MIGRATION_FLAG="$(getprop persist.gammaos.v1.2.migration)"

if [ "$MIGRATION_FLAG" = "0" ]; then
    # Ensure /data/GammaPad exists
    if [ ! -d /data/GammaPad ]; then
        mkdir -p /data/GammaPad
    fi

    # Create ffpwm file with value 0
    echo 0 > /data/GammaPad/ffpwm

    # Reset QS tiles
    settings put secure sysui_qs_tiles default

    # Mark migration as done
    setprop persist.gammaos.v1.2.migration 1
fi

#!/system/bin/sh

MIGRATION_FLAG="$(getprop persist.gammaos.v1.2.migration)"

# Treat anything that is not "1" (including empty) as "0" / not migrated
if [ "$MIGRATION_FLAG" != "1" ]; then
    # Ensure /data/GammaPad exists
    if [ ! -d /data/GammaPad ]; then
        mkdir -p /data/GammaPad
    fi

    # Create/update ffpwm file with value 0
    echo 0 > /data/GammaPad/ffpwm

    # Reset QS tiles
    settings put secure sysui_qs_tiles default

    # Copy GammaEQ Preset
    mkdir -p /sdcard/GammaEQ
    cp /vendor/etc/Sparkle-406H.txt /sdcard/GammaEQ/Sparkle-406H.txt

    # Mark migration as done
    setprop persist.gammaos.v1.2.migration 1
fi

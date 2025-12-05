#!/system/bin/sh

mkdir -p /data/GammaPad

su -c 'cat > /data/GammaPad/MAPPINGS << "EOF"
KEY_F9 KEY_F9
BTN_GAMEPAD BTN_GAMEPAD
BTN_EAST BTN_EAST
BTN_C BTN_C
BTN_NORTH BTN_NORTH
BTN_WEST BTN_WEST
BTN_Z BTN_Z
BTN_TL BTN_TL
BTN_TR BTN_TR
BTN_TL2 BTN_TL2
BTN_TR2 BTN_TR2
BTN_SELECT BTN_SELECT
BTN_START BTN_START
BTN_MODE KEY_ALL_APPLICATIONS
BTN_THUMBL BTN_THUMBL
BTN_THUMBR BTN_THUMBR
BTN_DPAD_UP BTN_DPAD_UP
BTN_DPAD_DOWN BTN_DPAD_DOWN
BTN_DPAD_LEFT BTN_DPAD_LEFT
BTN_DPAD_RIGHT BTN_DPAD_RIGHT
EOF'

setprop persist.gammaos.multidisplay.dual_focus 1
setprop persist.gammaos.dualstack.pkgs com.dsemu.drastic
setprop persist.gammaos.dualstack.enabled 1
setprop persist.gammaos.ultra_low_power_saving_mode 1
setprop persist.gammaos.secondary_home "com.android.launcher3/com.android.launcher3.secondarydisplay.SecondaryDisplayLauncher"
setprop persist.gammaos.immersive 1
settings put system lockscreen.disabled 1
#locksettings set-disabled true
#setprop persist.gammaos.retroarch.secondary_display 1

setprop persist.gammaos.secondary_display.enabled 1
setprop persist.gammaos.secondary_display.packages "org.mupen64plusae.v3.fzurita,com.retroarch.aarch64,com.flycast.emulator,org.ppsspp.ppsspp"

setprop persist.gammaos.launch.guard.enabled 1
setprop persist.gammaos.launch.guard.callers "com.magneticchen.daijishou,org.es_de.frontend"
setprop persist.gammaos.launch.guard.targets "com.retroarch.aarch64,org.ppsspp.ppsspp,org.mupen64plusae.v3.fzurita,com.flycast.emulator"

#settings put secure sysui_qs_tiles internet,bt,performance,dualstack,gammashader,gammadualfocus,deepsleepmode,immersivemode,rotation,abxy,analogsensitivity,dpadAnalogToggle,analogdeadzone,analogcalibration,analogaxis,rightanalogaxis,mappingeditor,retroarchmenubuttonoverride

launcheruser=$( stat -c "%U" /data/data/com.dsemu.drastic)
launchergroup=$( stat -c "%G" /data/data/com.dsemu.drastic)
rm -rf /data/data/com.dsemu.drastic/*
tar -xvf /vendor/etc/drastic.tar.gz -C /
chown -R $launcheruser:$launchergroup /data/data/com.dsemu.drastic

setprop persist.gammaos.shader.lcd3x.brighten_lcd 4.0
setprop persist.gammaos.shader.lcd3x.brighten_scanlines 4.0
setprop persist.gammaos.shader.lcd3x.grid_px_x 1.0
setprop persist.gammaos.shader.lcd3x.grid_px_y 3.0
setprop persist.gammaos.shader.type lcd3x

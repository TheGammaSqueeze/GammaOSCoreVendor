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

settings put global window_animation_scale 0
settings put global transition_animation_scale 0
settings put global animator_duration_scale 0

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

pm grant com.dsemu.drastic android.permission.RECORD_AUDIO
cmd appops set com.dsemu.drastic RECORD_AUDIO allow

tar -xvf /vendor/etc/GammaEQ.tar.gz -C /

launcheruser=$( stat -c "%U" /data/data/com.flycast.emulator)
launchergroup=$( stat -c "%G" /data/data/com.flycast.emulator)
tar -xJvf /vendor/etc/flycast.tar.xz -P -C /
chown -R $launcheruser:$launchergroup /data/data/com.flycast.emulator
chown -R $launcheruser:ext_data_rw /sdcard/Android/data/com.flycast.emulator

setprop persist.gammaos.shader.lcd3x.brighten_lcd 4.0
setprop persist.gammaos.shader.lcd3x.brighten_scanlines 4.0
setprop persist.gammaos.shader.lcd3x.grid_px_x 1.0
setprop persist.gammaos.shader.lcd3x.grid_px_y 3.0
#setprop persist.gammaos.shader.type lcd3x

setprop persist.sys.gammaeq.spk_only 1
setprop persist.sys.gammaeq.force 0
setprop persist.sys.gammaeq.preamp_db -1.0
setprop persist.sys.gammaeq.postgain_db 0

setprop persist.sys.spk.cryst 1
setprop persist.sys.spk.cryst.amount 4.0
setprop persist.sys.spk.cryst.mix 0.25
setprop persist.sys.spk.cryst.hz 11500
setprop persist.sys.spk.cryst.pregain_db -8
setprop persist.sys.spk.cryst.postgain_db 3.0161133
setprop persist.sys.spk.cryst.pre 0.40
setprop persist.sys.spk.cryst.fc 11500
setprop persist.sys.spk.cryst.limit 0.30

setprop persist.sys.spk.lbp 1
setprop persist.sys.spk.lbp.fc 160
setprop persist.sys.spk.lbp.thr 0.6934932
setprop persist.sys.spk.lbp.atk 4
setprop persist.sys.spk.lbp.rel 110

setprop persist.sys.spk.mp 1
setprop persist.sys.spk.mp.hpf 220
setprop persist.sys.spk.mp.lpf 5800
setprop persist.sys.spk.mp.thr 0.92
setprop persist.sys.spk.mp.atk 2
setprop persist.sys.spk.mp.rel 120

setprop persist.sys.spk.peq 1
setprop persist.sys.spk.peq.b0 1.30
setprop persist.sys.spk.peq.b1 -1.40
setprop persist.sys.spk.peq.b2 0.40197754
setprop persist.sys.spk.peq.a1 0
setprop persist.sys.spk.peq.a2 0
setprop persist.sys.spk.peq.pregain 1.0
setprop persist.sys.spk.peq.keepheadroom 1
setprop persist.sys.spk.peq.limit 0

setprop persist.sys.spk.peq2 1
setprop persist.sys.spk.peq2.b0 0.6289673
setprop persist.sys.spk.peq2.b1 -2.9190538
setprop persist.sys.spk.peq2.b2 0.18703546
setprop persist.sys.spk.peq2.a1 0
setprop persist.sys.spk.peq2.a2 0

setprop persist.sys.spk.wide 1
setprop persist.sys.spk.wide.mix 0.79901123
setprop persist.sys.spk.wide.hpf 5500
setprop persist.sys.spk.wide.amount 2.0
setprop persist.sys.spk.wide.pre 4.0561523
setprop persist.sys.spk.wide.limit 1.0
setprop persist.sys.spk.wide.fc 16000.0

setprop persist.sys.gammaeq.enable 1

# lineage_tv_* runtime enforcement:
# Keep SystemUI (non-TV) stable by forcing keyguard and doze/AOD state off.
(
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
    done

    # Gate to lineage_tv builds only.
    if ! getprop ro.lineage.version | grep -q "tv_"; then
        exit 0
    fi

    # Mark device as provisioned to avoid any policy paths that reassert lock-like UI.
    settings put global device_provisioned 1 >/dev/null 2>&1 || true
    settings put secure user_setup_complete 1 >/dev/null 2>&1 || true

    # Disable doze / AOD related settings that commonly surface the clock UI.
    settings put secure doze_enabled 0 >/dev/null 2>&1 || true
    settings put secure doze_always_on 0 >/dev/null 2>&1 || true
    settings put secure screensaver_enabled 0 >/dev/null 2>&1 || true

    # Disable lockscreen related secure settings (best-effort).
    settings put secure lockscreen.disabled 1 >/dev/null 2>&1 || true
    settings put secure lock_screen_lock_after_timeout 0 >/dev/null 2>&1 || true
    settings put secure lock_screen_show_notifications 0 >/dev/null 2>&1 || true
    settings put secure lock_screen_allow_private_notifications 0 >/dev/null 2>&1 || true
    settings put secure lockscreen_show_controls 0 >/dev/null 2>&1 || true
    settings put secure lockscreen_show_wallet 0 >/dev/null 2>&1 || true

    # Best-effort: disable SystemUI keyguard components so keyguard views cannot be shown.
    # Component names vary by branch; failures are ignored.
    pm disable-user --user 0 com.android.systemui/.keyguard.KeyguardService >/dev/null 2>&1 || true
    pm disable-user --user 0 com.android.systemui/.keyguard.KeyguardViewMediatorService >/dev/null 2>&1 || true
    pm disable-user --user 0 com.android.systemui/com.android.systemui.keyguard.KeyguardService >/dev/null 2>&1 || true

    # Dismiss keyguard once if anything tried to show it.
    wm dismiss-keyguard >/dev/null 2>&1 || true

    # IME enforcement (optional but helps your hybrid UX):
    # remove Leanback IME for user 0 if present, set LatinIME as default if installed.
    if pm list packages | grep -q "com.android.inputmethod.leanback"; then
        pm uninstall --user 0 com.android.inputmethod.leanback >/dev/null 2>&1 || true
        pm disable-user --user 0 com.android.inputmethod.leanback >/dev/null 2>&1 || true
    fi
    if pm list packages | grep -q "com.android.inputmethod.latin"; then
        ime enable com.android.inputmethod.latin/.LatinIME >/dev/null 2>&1 || true
        ime set com.android.inputmethod.latin/.LatinIME >/dev/null 2>&1 || true
    fi
) &

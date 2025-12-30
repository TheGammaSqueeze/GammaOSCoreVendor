#!/system/bin/sh

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

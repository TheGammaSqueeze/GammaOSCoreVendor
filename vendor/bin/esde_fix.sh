#!/system/bin/sh
#
# esde_fix.sh
#
# Run as root, no arguments (e.g. from init or manually):
#   su -c /system/bin/esde_themes_bind.sh
#
# Behaviour:
#   - Ensures /data/user/0/org.es_de.frontend/files/themes is bind-mounted to
#     /storage/emulated/0/Android/data/org.es_de.frontend/files/themes
#   - Reacts to:
#       * changes to /data/system/packages.list (install/uninstall)
#       * creation/deletion of /storage/emulated/0/Android/data/org.es_de.frontend
#

APP_PKG="org.es_de.frontend"

# Internal and external paths
INTERNAL_BASE="/data/user/0/${APP_PKG}/files"
INTERNAL_THEMES="${INTERNAL_BASE}/themes"

EXTERNAL_APP_ROOT="/storage/emulated/0/Android/data/${APP_PKG}"
EXTERNAL_THEMES="${EXTERNAL_APP_ROOT}/files/themes"

PACKAGES_DIR="/data/system"
PACKAGES_LIST="${PACKAGES_DIR}/packages.list"

ANDROID_DATA_DIR="/storage/emulated/0/Android/data"

log() {
    echo "[esde_themes_bind] $*" >&2
}

# Resolve our absolute script path for inotifyd
get_script_path() {
    # If $0 is already absolute, use it
    case "$0" in
        /*)
            echo "$0"
            return
            ;;
    esac

    # Try readlink -f if available
    if command -v readlink >/dev/null 2>&1; then
        p="$(readlink -f "$0" 2>/dev/null)"
        if [ -n "$p" ]; then
            echo "$p"
            return
        fi
    fi

    # Fallback: prepend current directory
    echo "$(pwd)/$0"
}

get_app_uid() {
    # Preferred: use cmd package list packages -U
    if command -v cmd >/dev/null 2>&1; then
        uid_line="$(cmd package list packages -U "${APP_PKG}" 2>/dev/null | head -n1)"
        log "get_app_uid: cmd output='${uid_line}'"
        if [ -n "${uid_line}" ]; then
            uid="$(printf "%s" "${uid_line}" | sed -n 's/.*uid://p' | awk '{print $1}')"
            if [ -n "${uid}" ]; then
                log "get_app_uid: parsed uid=${uid}"
                echo "${uid}"
                return
            fi
        fi
    fi

    # Fallback: packages.list
    if [ -r "${PACKAGES_LIST}" ]; then
        uid="$(awk '$1=="'"${APP_PKG}"'" {print $2}' "${PACKAGES_LIST}" 2>/dev/null | head -n1)"
        log "get_app_uid: packages.list uid='${uid}'"
        if [ -n "${uid}" ]; then
            echo "${uid}"
            return
        fi
    fi

    log "get_app_uid: no UID found for ${APP_PKG}"
    echo ""
}

is_bind_mounted() {
    if command -v mountpoint >/dev/null 2>&1; then
        mountpoint -q "${EXTERNAL_THEMES}" 2>/dev/null && return 0
    fi
    grep -q " ${EXTERNAL_THEMES} " /proc/mounts 2>/dev/null && return 0
    return 1
}

ensure_bind_mount() {
    log "ensure_bind_mount: checking bind status..."
    if is_bind_mounted; then
        log "ensure_bind_mount: bind already in place: ${INTERNAL_THEMES} -> ${EXTERNAL_THEMES}"
        return 0
    fi

    APP_UID="$(get_app_uid)"
    if [ -z "${APP_UID}" ]; then
        log "ensure_bind_mount: app ${APP_PKG} not installed yet (no UID), skipping bind"
        return 1
    fi

    log "ensure_bind_mount: using APP_UID=${APP_UID}"

    # Ensure internal paths exist (with themes-list)
    log "ensure_bind_mount: mkdir -p ${INTERNAL_THEMES}/themes-list"
    mkdir -p "${INTERNAL_THEMES}/themes-list" 2>/dev/null

    log "ensure_bind_mount: chown -R ${APP_UID}:${APP_UID} ${INTERNAL_BASE}"
    chown -R "${APP_UID}:${APP_UID}" "${INTERNAL_BASE}" 2>/dev/null

    if command -v restorecon >/dev/null 2>&1; then
        log "ensure_bind_mount: restorecon -R ${INTERNAL_BASE}"
        restorecon -R "${INTERNAL_BASE}" 2>/dev/null
    else
        log "ensure_bind_mount: restorecon not available, skipping"
    fi

    # Ensure external app root and themes path exist
    log "ensure_bind_mount: mkdir -p ${EXTERNAL_THEMES}"
    mkdir -p "${EXTERNAL_THEMES}" 2>/dev/null

    # Re-check in case something else mounted it
    if is_bind_mounted; then
        log "ensure_bind_mount: bind now present after mkdir, not mounting again"
        return 0
    fi

    log "ensure_bind_mount: mount --bind ${INTERNAL_THEMES} ${EXTERNAL_THEMES}"
    if mount --bind "${INTERNAL_THEMES}" "${EXTERNAL_THEMES}" 2>/dev/null; then
        log "ensure_bind_mount: bind mount successful"
        return 0
    else
        log "ensure_bind_mount: ERROR: mount --bind failed"
        return 1
    fi
}

teardown_bind_if_uninstalled() {
    APP_UID="$(get_app_uid)"
    if [ -n "${APP_UID}" ]; then
        log "teardown_bind_if_uninstalled: app still installed (uid=${APP_UID}), nothing to do"
        return
    fi

    if is_bind_mounted; then
        log "teardown_bind_if_uninstalled: app gone; umount ${EXTERNAL_THEMES}"
        umount "${EXTERNAL_THEMES}" 2>/dev/null || log "teardown_bind_if_uninstalled: WARN: umount failed"
    else
        log "teardown_bind_if_uninstalled: no bind mount present"
    fi
}

handler_mode() {
    # Called by inotifyd:
    #   $1 = EVENTS
    #   $2 = FILE
    #   $3 = DIRFILE (for dir watches)
    local events="$1"
    local file="$2"
    local dir="$3"

    log "handler_mode: events='${events}' file='${file}' dir='${dir}'"

    # packages.list changed
    if [ "${file}" = "${PACKAGES_LIST}" ]; then
        log "handler_mode: packages.list changed"
        APP_UID="$(get_app_uid)"
        if [ -n "${APP_UID}" ]; then
            ensure_bind_mount
        else
            teardown_bind_if_uninstalled
        fi
        exit 0
    fi

    # Directory watch on ANDROID_DATA_DIR: child created/deleted/moved
    if [ "${dir}" = "${ANDROID_DATA_DIR}" ]; then
        child="${file}"
        base_child="$(basename "${child}")"
        log "handler_mode: dir event in ${ANDROID_DATA_DIR}, child='${child}' base='${base_child}'"
        if [ "${base_child}" = "${APP_PKG}" ]; then
            case "${events}" in
                *n*|*m*)
                    log "handler_mode: ${APP_PKG} dir created/moved in; ensure bind"
                    ensure_bind_mount
                    ;;
                *d*|*y*)
                    log "handler_mode: ${APP_PKG} dir deleted/moved out; maybe teardown bind"
                    teardown_bind_if_uninstalled
                    ;;
            esac
        fi
        exit 0
    fi

    log "handler_mode: event not relevant, ignoring"
    exit 0
}

main_mode() {
    SCRIPT_PATH="$(get_script_path)"
    log "main_mode: starting; SCRIPT_PATH='${SCRIPT_PATH}'"
    log "main_mode: INTERNAL_THEMES='${INTERNAL_THEMES}', EXTERNAL_THEMES='${EXTERNAL_THEMES}'"

    # Try once at startup (handles case where app is already installed)
    ensure_bind_mount

    # Ensure watch roots exist
    mkdir -p "${ANDROID_DATA_DIR}" 2>/dev/null
    mkdir -p "${PACKAGES_DIR}" 2>/dev/null
    [ -f "${PACKAGES_LIST}" ] || touch "${PACKAGES_LIST}"

    if is_bind_mounted; then
        log "main_mode: bind already active at startup; will keep it in sync"
    else
        log "main_mode: bind not yet active; will react when app installs or external path appears"
    fi

    # Use toybox inotifyd or inotifyd from PATH
    if command -v inotifyd >/dev/null 2>&1; then
        log "main_mode: exec inotifyd '${SCRIPT_PATH}' '${PACKAGES_LIST}:ce' '${ANDROID_DATA_DIR}:mnyd'"
        exec inotifyd "${SCRIPT_PATH}" "${PACKAGES_LIST}:ce" "${ANDROID_DATA_DIR}:mnyd"
    elif command -v toybox >/dev/null 2>&1; then
        log "main_mode: exec toybox inotifyd '${SCRIPT_PATH}' '${PACKAGES_LIST}:ce' '${ANDROID_DATA_DIR}:mnyd'"
        exec toybox inotifyd "${SCRIPT_PATH}" "${PACKAGES_LIST}:ce" "${ANDROID_DATA_DIR}:mnyd"
    else
        log "main_mode: ERROR: inotifyd not available; falling back to polling"
        while true; do
            APP_UID="$(get_app_uid)"
            if [ -n "${APP_UID}" ]; then
                ensure_bind_mount
            else
                teardown_bind_if_uninstalled
            fi
            sleep 10
        done
    fi
}

# Entry point:
# - Called directly: no args -> main_mode
# - Called by inotifyd: >=2 args -> handler_mode
if [ $# -ge 2 ]; then
    log "entry: handler_mode with $# args: '$*'"
    handler_mode "$@"
else
    log "entry: main_mode (no args)"
    main_mode
fi

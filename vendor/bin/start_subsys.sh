#! /vendor/bin/sh
#=============================================================================
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# All rights reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#=============================================================================

# Helpers: wait for dir / file existence (10 tries, 1s sleep)
# Wait up to 10s for a directory to exist
wait_for_dir() {
    dir_path="$1"
    label="${2:-$1}"

    i=0
    while [ "$i" -lt 10 ]; do
        if [ -d "$dir_path" ]; then
            echo "[OK] Dir present: $label"
            return 0
        fi
        i=$((i + 1))
        sleep 1
    done

    echo "[TIMEOUT] Dir not found after 10s: $label"
    return 1
}

# Wait up to 10s for a file to exist
wait_for_file() {
    file_path="$1"
    label="${2:-$1}"

    i=0
    while [ "$i" -lt 10 ]; do
        if [ -e "$file_path" ]; then
            echo "[OK] File present: $label"
            return 0
        fi
        i=$((i + 1))
        sleep 1
    done

    echo "[TIMEOUT] File not found after 10s: $label"
    return 1
}

# Ensure remoteproc class exists before anything else
rproc_class="/sys/class/remoteproc"
wait_for_dir "$rproc_class" "remoteproc class" || exit 1

# Ensure at least one remoteprocN directory exists
# Use a glob that won't error when no match; test via 'set --' trick
# (POSIX-friendly approach to check if any /sys/class/remoteproc/remoteproc* directories are present)
# Retry up to 10 times (1s sleep) until at least one remoteproc* dir appears
set -- "$rproc_class"/remoteproc*
attempt=0
while [ "$1" = "$rproc_class/remoteproc*" ] && [ "$attempt" -lt 10 ]; do
    attempt=$((attempt + 1))
    echo "[RETRY $attempt/10] No remoteproc* directories yet under $rproc_class; waiting 1s."
    sleep 1
    set -- "$rproc_class"/remoteproc*  # re-expand the glob on each iteration
done

if [ "$1" = "$rproc_class/remoteproc*" ]; then
    echo "[TIMEOUT] No remoteproc* directories found under $rproc_class after 10s"
    exit 1
fi

# wait for the first remoteprocN dir
first_rproc_dir="$1"
wait_for_dir "$first_rproc_dir" "first remoteprocN dir" || exit 1

# remoteproc device directories for soccp/adsp/cdsp by name matching
soccp_path_file="$(grep -rl 'soccp' "$rproc_class"/remoteproc*/name 2>/dev/null | head -n1)"
[ -n "$soccp_path_file" ] && soccp_path_file="$(dirname "$soccp_path_file")"
adsp_path_file="$(grep -rl 'adsp' "$rproc_class"/remoteproc*/name 2>/dev/null | head -n1)"
[ -n "$adsp_path_file" ] && adsp_path_file="$(dirname "$adsp_path_file")"
cdsp_path_file="$(grep -rl 'cdsp' "$rproc_class"/remoteproc*/name 2>/dev/null | head -n1)"
[ -n "$cdsp_path_file" ] && cdsp_path_file="$(dirname "$cdsp_path_file")"

boot_mode_sh="$(getprop ro.boot.mode 2>/dev/null)"
echo "Subsystem starting in mode: $boot_mode_sh"

# remoteproc state file paths
soccp_state_file=""
adsp_state_file=""
cdsp_state_file=""

[ -n "$soccp_path_file" ] && [ -d "$soccp_path_file" ] && soccp_state_file="$soccp_path_file/state"
[ -n "$adsp_path_file" ] && [ -d "$adsp_path_file" ] && adsp_state_file="$adsp_path_file/state"
[ -n "$cdsp_path_file" ] && [ -d "$cdsp_path_file" ] && cdsp_state_file="$cdsp_path_file/state"

# Make sure 'state' files exist
soccp_state=""
adsp_state=""
cdsp_state=""

if [ -n "$soccp_state_file" ]; then
    wait_for_file "$soccp_state_file" "soccp state file" || exit 1
    soccp_state="$(cat "$soccp_state_file" 2>/dev/null)"
fi

if [ -n "$adsp_state_file" ]; then
    wait_for_file "$adsp_state_file" "adsp state file" || exit 1
    adsp_state="$(cat "$adsp_state_file" 2>/dev/null)"
fi

if [ -n "$cdsp_state_file" ]; then
    wait_for_file "$cdsp_state_file" "cdsp state file" || exit 1
    cdsp_state="$(cat "$cdsp_state_file" 2>/dev/null)"
fi

# Start soccp if not running/attached
if [[ "$soccp_state" != "running" ]] && [[ "$soccp_state" != "attached" ]]; then
    echo "Requesting soccp start"
    echo "start" > "$soccp_state_file"
fi

# Skip ADSP/CDSP in charger mode
if [[ "$boot_mode_sh" != "charger" ]]; then
    if [[ "$adsp_state" != "running" ]]; then
        echo "Requesting adsp start"
        echo "start" > "$adsp_state_file"
    fi

    if [[ "$cdsp_state" != "running" ]]; then
        echo "Requesting cdsp start"
        echo "start" > "$cdsp_state_file"
    fi
fi


#! /vendor/bin/sh
#=============================================================================
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# All rights reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#=============================================================================

SYSTEM_DLKM_DIR="/system_dlkm/lib/modules"
VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules"
MODPROBE="/vendor/bin/modprobe"

pagesize=$(getconf PAGE_SIZE)

if [[ "${pagesize}" == "16384" ]]; then
    SYSTEM_DLKM_DIR="/system_dlkm/lib/modules/16k-mode"
    VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules/16k-mode"
fi

if [ ! -d "${SYSTEM_DLKM_DIR}" ]; then
    echo "ERROR: SYSTEM_DLKM_DIR missing" >&2
    exit 1
fi

# Determine parallelism = number of online CPUs + 1
cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null)"
# Treat empty or invalid CPU count as failure; 1 is a valid value
if [ -z "${cpu_count}" ] || [ "${cpu_count}" -lt 1 ] 2>/dev/null; then
    echo "ERROR: invalid CPU count" >&2
    exit 1
fi

job_count=$((cpu_count + 1))
ret=0

# 1. Prepare Blocklist Regex
blocklist_regex=""
if [ -s "${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist" ]; then
    blocklist_regex=$(sed -n 's/^blocklist //p' "${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist" \
        | sed 's/[-_]/[_-]/g' \
        | tr '\n' '|' \
        | sed 's/|$//')
fi

for dir in ${SYSTEM_DLKM_DIR}; do
    cd "${dir}" || continue

    # 2. Get Files (Sorted by Size)
    if [ -n "${blocklist_regex}" ]; then
        all_files=$(ls -S *.ko 2>/dev/null | grep -E -v -w "${blocklist_regex}")
    else
        all_files=$(ls -S *.ko 2>/dev/null)
    fi

    [ -z "${all_files}" ] && continue

    # 3. Load files into positional parameters
    set -- ${all_files}

    # Initialize dynamic buckets: b0, b1, ... bN
    i=0
    while [ "${i}" -lt "${job_count}" ]; do
        eval "b${i}=''"
        i=$((i + 1))
    done

    # Distribute files round-robin across job_count buckets
    bucket=0
    while [ "$1" ]; do
        eval "b${bucket}=\"\${b${bucket}} \$1\""
        shift

        bucket=$((bucket + 1))
        if [ "${bucket}" -ge "${job_count}" ]; then
            bucket=0
        fi
    done

    # 4. Launch Parallel Loaders
    pids=""
    i=0
    while [ "${i}" -lt "${job_count}" ]; do
        eval "bucket_files=\$b${i}"
        if [ -n "${bucket_files}" ]; then
            ( ${MODPROBE} -b -s -d "${dir}" -a ${bucket_files} > /dev/null ) &
            pids="${pids} $!"
        fi
        i=$((i + 1))
    done

    # Wait for all background jobs and capture failures
    for pid in ${pids}; do
        if ! wait "${pid}"; then
            echo "ERROR: modprobe failed for a module batch in '${dir}' (pid: ${pid})" >&2
            ret=1
        fi
    done
done

exit "${ret}"

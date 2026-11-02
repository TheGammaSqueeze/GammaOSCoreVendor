#! /vendor/bin/sh
#=============================================================================
# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# All rights reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#=============================================================================

VENDOR_DIR="/vendor/lib/modules"
VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules"
MODPROBE="/vendor/bin/modprobe"
POSSIBLE_DIRS="${VENDOR_DLKM_DIR} ${VENDOR_DIR}"

pagesize=$(getconf PAGE_SIZE)

if [[ "${pagesize}" == "16384" ]]; then
    VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules/16k-mode"
    POSSIBLE_DIRS="${VENDOR_DLKM_DIR}"
fi

audio_arch="$(getprop ro.boot.audio)"

# Check for parallel support quietly
if echo "test" | xargs -P 2 true 2>/dev/null; then
    XARGS_OPTS="-P 4"
else
    XARGS_OPTS=""
fi

for dir in ${POSSIBLE_DIRS}; do
    [ -f "${dir}/modules.load" ] || continue

    # 1. GENERATE BLOCKLIST REGEX
    # Determine audio blocklist
    if [ "${audio_arch}" = "audioreach" ]; then
        audio_blk="${dir}/modules.audio.ar.blocklist"
    else
        audio_blk="${dir}/modules.audio.legacy.blocklist"
    fi

    # Extract blocked names:
    # 1. Cat files (ignore errors).
    # 2. Grep for "blocklist" lines.
    # 3. sed: remove "blocklist " prefix, normalize - to _.
    # 4. sort -u: deduplicate blocklist.
    # 5. tr: join with '|' to create regex (mod1|mod2).
    # 6. sed: remove trailing pipe.
    block_pattern=$(cat "${dir}/modules.blocklist" "${audio_blk}" 2>/dev/null \
        | grep "^blocklist[[:space:]]" \
        | sed 's/^blocklist[[:space:]]\+//;s/-/_/g' \
        | sort -u \
        | tr '\n' '|' \
        | sed 's/|$//')

    # 2. DEFINE FILTER FUNCTION
    # This function streams modules.load and filters out blocked modules.
    # We use a function to easily repeat the stream for canary vs batch loading.
    get_modules() {
        # Stream modules.load -> normalize -> filter empty/comments
        sed 's/-/_/g;s/^[[:space:]]*//;s/[[:space:]]*$//' "${dir}/modules.load" \
        | grep -v '^#' \
        | grep -v '^$' \
        | if [ -n "${block_pattern}" ]; then
              # If blocklist exists, use grep -v -E "mod1|mod2"
              # usage of () ensures strict matching boundaries if needed,
              # but typically ^(pattern)$ is safest for exact match.
              grep -v -E "^(${block_pattern})$"
          else
              # No blocklist, pass through
              cat
          fi
    }

    # 3. CANARY LOAD (First Module)
    # Grab the first module to test the directory
    first_module=$(get_modules | head -n 1)

    # If list is empty, move to next dir
    [ -n "${first_module}" ] || continue

    # Try loading the first module
    if ! "${MODPROBE}" -b -s -d "${dir}" -a "${first_module}" >/dev/null 2>&1; then
        # If canary fails, this directory is likely incompatible. Skip.
        continue
    fi

    # 4. BATCH LOAD (Rest of modules)
    # Stream the list again, remove the first line (already loaded), and batch load the rest.
    # We allow modprobe to handle any remaining duplicates.
    get_modules \
        | sed '1d' \
        | xargs ${XARGS_OPTS} -n 32 "${MODPROBE}" -b -d "${dir}" -a >/dev/null 2>&1

    setprop vendor.all.modules.ready 1
    exit 0
done

exit 1

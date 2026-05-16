#!/usr/bin/env bash
# Apply selinux contexts from an Android file_contexts-style list to the
# matching files in a source tree, as xattrs. Paths in the contexts file
# are interpreted relative to the partition mount point.
#
# Usage: apply_contexts.sh <source_dir> <contexts_file>
#
# The contexts file format is: <path> <selinux_context>
# where <path> may have regex-escaped literals like '\.' and '\+'.
# We do not interpret regex - the file is a static label list for our use.

set -euo pipefail

VENDOR_DIR="$1"
CONTEXTS_FILE="$2"

if [ ! -d "$VENDOR_DIR" ] || [ ! -f "$CONTEXTS_FILE" ]; then
    echo "usage: $0 <vendor_dir> <contexts_file>" >&2
    exit 1
fi

applied=0
skipped=0
while IFS=' ' read -r raw_path context; do
    [ -z "$raw_path" ] && continue
    # Unescape the small regex set the contexts file actually uses
    rel_path="${raw_path//\\./.}"
    rel_path="${rel_path//\\+/+}"
    if [ "$rel_path" = "/" ]; then
        target="$VENDOR_DIR"
    else
        target="$VENDOR_DIR$rel_path"
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
        setfattr -h -n security.selinux -v "$context" "$target" 2>/dev/null
        applied=$((applied+1))
    else
        skipped=$((skipped+1))
    fi
done < "$CONTEXTS_FILE"

echo "apply_contexts: applied=$applied skipped=$skipped"

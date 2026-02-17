#!/usr/bin/env bash
set -euo pipefail

CTX_FILE="selinux_contexts.txt"

# Default contexts to use when stat can't read an xattr context.
default_ctx_for_path() {
  # Input: absolute path like "/etc/init/init.foo.rc"
  local p="$1"

  # Normalize: ensure leading slash
  [[ "$p" != /* ]] && p="/$p"

  case "$p" in
    /etc/*)      echo "u:object_r:vendor_configs_file:s0" ;;
    /apex/*)     echo "u:object_r:vendor_apex_file:s0" ;;
    /app/*)      echo "u:object_r:vendor_app_file:s0" ;;
    /overlay/*)  echo "u:object_r:vendor_overlay_file:s0" ;;
    /bin/*)      echo "u:object_r:vendor_file:s0" ;;
    /firmware/*) echo "u:object_r:vendor_file:s0" ;;
    /lib/*)      echo "u:object_r:vendor_file:s0" ;;
    /lib64/*)    echo "u:object_r:vendor_file:s0" ;;
    /usr/*)      echo "u:object_r:vendor_file:s0" ;;
    /odm/*)      echo "u:object_r:vendor_file:s0" ;;
    /*)          echo "u:object_r:vendor_file:s0" ;; # includes "/" root and everything else
  esac
}

# Escape file_contexts regex metacharacters so paths are treated literally by e2fsdroid -S.
escape_fc_regex() {
  python3 - "$1" <<'PY'
import sys
s = sys.argv[1]
special = set(r'.^$*+?{}[]()|\ ')
special.add('\\')
out = []
for ch in s:
    if ch in special:
        out.append('\\' + ch)
    else:
        out.append(ch)
print(''.join(out))
PY
}

tmp_gen="$(mktemp)"
tmp_new="$(mktemp)"
trap 'rm -f "$tmp_gen" "$tmp_new"' EXIT

# Generate fresh "path context" pairs from vendor/ tree
find vendor -print0 \
| while IFS= read -r -d '' p; do
    # Convert vendor/... -> /...
    rel="${p#vendor}"
    rel="${rel#/}"

    if [[ -z "$rel" ]]; then
      abs="/"
    else
      abs="/$rel"
      abs="${abs%/}"
    fi

    # Try to read SELinux context, fall back if unavailable
    ctx=""
    if ! ctx="$(stat -c '%C' "$p" 2>/dev/null)"; then
      ctx="$(default_ctx_for_path "$abs")"
    fi
    # Some stat builds output "?" or empty when no xattr, treat as missing too
    if [[ -z "$ctx" || "$ctx" == "?" ]]; then
      ctx="$(default_ctx_for_path "$abs")"
    fi

    esc_path="$(escape_fc_regex "$abs")"
    printf '%s %s\n' "$esc_path" "$ctx"
  done \
| LC_ALL=C sort -u > "$tmp_gen"

# Append only missing path keys (first column)
awk 'NR==FNR{seen[$1]=1; next} !seen[$1]' "$CTX_FILE" "$tmp_gen" > "$tmp_new"

if [[ -s "$tmp_new" ]]; then
  cat "$tmp_new" >> "$CTX_FILE"
  echo "Appended $(wc -l < "$tmp_new") new SELinux context entries to $CTX_FILE"
else
  echo "No missing SELinux context entries. $CTX_FILE unchanged."
fi

# Expected usage:
# MKE2FS_CONFIG=mke2fs.conf ./mke2fs -O ^has_journal,^sparse_super -L vendor -M /vendor -m 0 -t ext4 -b 4096 vendor.img 200000
# ./e2fsdroid -e -T 1230768000 -S selinux_contexts.txt -f vendor/ -a / vendor.img

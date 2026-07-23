#!/usr/bin/env bash
# Restore SELinux contexts from selinux_contexts.txt back onto the vendor/ tree.
# Each line in the context file is: <path> <context>
# where <path> is an absolute path (e.g. /etc/foo) that maps to vendor/etc/foo,
# and may contain file_contexts regex escaping (backslash before metacharacters).
set -euo pipefail

CTX_FILE="selinux_contexts.txt"
VENDOR_DIR="vendor"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (sudo) to set SELinux contexts." >&2
  exit 1
fi

if [[ ! -f "$CTX_FILE" ]]; then
  echo "Context file '$CTX_FILE' not found." >&2
  exit 1
fi

if [[ ! -d "$VENDOR_DIR" ]]; then
  echo "Vendor directory '$VENDOR_DIR' not found." >&2
  exit 1
fi

applied=0
missing=0
failed=0

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue

  # Context is the last whitespace-separated field; path is everything before it.
  ctx="${line##* }"
  path="${line% *}"

  # Unescape file_contexts regex escaping: drop the backslash before escaped chars.
  path="$(printf '%s' "$path" | sed 's/\\\(.\)/\1/g')"

  # Map absolute path "/foo" -> "vendor/foo"; "/" -> "vendor".
  if [[ "$path" == "/" ]]; then
    target="$VENDOR_DIR"
  else
    target="$VENDOR_DIR${path}"
  fi

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    echo "MISSING: $target" >&2
    ((missing++)) || true
    continue
  fi

  if chcon -h "$ctx" "$target" 2>/dev/null; then
    ((applied++)) || true
  else
    echo "FAILED:  $ctx -> $target" >&2
    ((failed++)) || true
  fi
done < "$CTX_FILE"

echo "Done. Applied: $applied, Missing: $missing, Failed: $failed"

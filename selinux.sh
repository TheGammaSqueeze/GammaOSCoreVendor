#!/bin/bash
# Refresh selinux_contexts.txt from the vendor/ tree, ADDITIVELY.
#
# e2fsdroid consumes this file as file_contexts (via -S): each line is
# "<path-regex> <context>", path rooted at the vendor mount (vendor/ itself is
# ".", vendor/app is "/app", ...). Because the path field is a REGEX, every
# regex metacharacter is escaped so each line matches its literal path; an
# unescaped "+" (e.g. lost+found) or "[" would silently fail to match and
# e2fsdroid would abort labelling that inode. Contexts come from each file's
# security.selinux xattr, so this runs as root.
#
# Additive: existing lines are preserved verbatim; only paths not already
# present are appended. Delete selinux_contexts.txt first to rebuild from scratch.
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then exec sudo -E "$0" "$@"; fi
cd "$(dirname "$0")"
SRC="${1:-vendor}"

OUT=selinux_contexts.txt
touch "$OUT"

SRC="$SRC" python3 - "$OUT" <<'PY'
import os, sys, subprocess
out = sys.argv[1]
SPECIAL = set('.^$*+?()[]{}|\\')
def esc(p):
    if p == '.':                 # vendor root: keep permissive single-char match
        return '.'
    return ''.join('\\'+c if c in SPECIAL else c for c in p)

# Existing paths (field 1, already escaped) -> skip set.
existing = set()
with open(out, encoding='utf-8', errors='replace') as f:
    for ln in f:
        ln = ln.rstrip('\n')
        if ln.strip():
            existing.add(ln[:ln.rfind(' ')])

# Generate "<path> <context>" for every entry, path rooted at the vendor mount.
raw = subprocess.run(
    "cd %s && find . -exec stat -c '%%n %%C' {} \;" % os.environ["SRC"],
    shell=True, capture_output=True, text=True, check=True).stdout

added = 0
with open(out, 'a', encoding='utf-8') as f:
    for ln in raw.splitlines():
        if not ln.strip():
            continue
        i = ln.rfind(' ')
        path, ctx = ln[:i], ln[i+1:]
        path = '/' + path[2:] if path.startswith('./') else path   # ./app -> /app
        ep = esc(path)
        if ep in existing:
            continue
        f.write(ep + ' ' + ctx + '\n')
        existing.add(ep)
        added += 1

total = sum(1 for _ in open(out, encoding='utf-8', errors='replace'))
print("selinux_contexts.txt: appended %d entr%s; %d total"
      % (added, "y" if added == 1 else "ies", total))
PY

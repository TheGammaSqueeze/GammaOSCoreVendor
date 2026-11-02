#!/bin/bash
# Import a stock vendor ext4 image into this tree: extracts the files into
# vendor/ and writes fs_config.txt, selinux_contexts.txt and vendor_dirs.txt
# straight from the image's inodes (uid, gid, mode, security.selinux and
# security.capability), so nothing depends on the host keeping ownership or
# xattrs. fs_config.sh / selinux.sh do the same from a mounted tree; this is
# the route for a stock image, whose labels debugfs rdump does not copy.
#
# Usage: ./import_image.sh <vendor.img>
# Existing vendor/, fs_config.txt, selinux_contexts.txt and vendor_dirs.txt are
# replaced. Runs as root (the extracted tree keeps the image's ownership).
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then exec sudo -E "$0" "$@"; fi
cd "$(dirname "$0")"
IMG="$(readlink -f "${1:?usage: $0 <vendor.img>}")"

rm -rf vendor
mkdir vendor
debugfs -R "rdump / vendor" "$IMG" 2>/dev/null

IMG="$IMG" python3 - <<'PY'
import os, re, struct, subprocess, stat as st
IMG = os.environ["IMG"]
SPECIAL = set('.^$*+?()[]{}|\\')
def esc(p):
    if p == '.':
        return '.'
    return ''.join('\\' + c if c in SPECIAL else c for c in p)

# every path in the extracted tree, rooted at the vendor mount
paths = []
for dp, dns, fns in os.walk("vendor"):
    dns.sort()
    for n in [dp] + sorted(os.path.join(dp, f) for f in fns + [d for d in dns if os.path.islink(os.path.join(dp, d))]):
        rel = os.path.relpath(n, "vendor")
        paths.append('' if rel == '.' else rel)
paths = sorted(set(paths))

# One debugfs batch: stat + both xattrs for every path. Each command is echoed
# as "debugfs: <cmd>", which splits the output per path.
cmds = []
for p in paths:
    ip = '/' + p
    cmds += ['stat "%s"' % ip, 'ea_get -x "%s" security.capability' % ip, 'ea_get "%s" security.selinux' % ip]
# stderr merged into stdout so each command's error text stays in its section
out = subprocess.run("debugfs -f - '%s' 2>&1" % IMG, shell=True,
                     input="\n".join(cmds) + "\n", capture_output=True, text=True).stdout
blocks = []
for s in out.split('debugfs: ')[1:]:
    cmd, _, body = s.partition('\n')
    blocks.append((cmd, body))
assert len(blocks) == len(cmds), (len(blocks), len(cmds))

fs_lines, se_lines, dirs = [], [], []
for i, p in enumerate(paths):
    statb = blocks[3 * i][1]
    capb = blocks[3 * i + 1][1]
    seb = blocks[3 * i + 2][1]
    m = re.search(r'Mode:\s+(\d+)', statb)
    u = re.search(r'User:\s+(\d+)\s+Group:\s+(\d+)', statb)
    t = re.search(r'Type:\s+(\S+)', statb)
    if not (m and u and t):
        raise SystemExit("cannot stat /%s:\n%s" % (p, statb))
    mode = int(m.group(1), 8)
    if t.group(1) == 'directory' and p:
        dirs.append(p)
    caps = 0
    # "security.capability (20) = 01 00 00 02 ..." (vfs_cap_data), or "key not found"
    cm = re.search(r'security\.capability \(\d+\) = (.*)', capb)
    hx = re.findall(r'[0-9a-f]{2}', cm.group(1)) if cm else []
    if hx:
        raw = bytes(int(h, 16) for h in hx)
        if len(raw) >= 12:
            lo, = struct.unpack_from('<I', raw, 4)
            hi, = struct.unpack_from('<I', raw, 12) if len(raw) >= 16 else (0,)
            caps = lo | (hi << 32)
    fs_lines.append("%s %s %s %04o capabilities=0x%x" % (p, u.group(1), u.group(2), mode, caps))
    ctx = seb.strip().split('\n')[-1].strip()
    ctx = ctx.split('=', 1)[1].strip() if '=' in ctx else ctx
    ctx = ctx.strip('"').replace('\\000', '').strip()
    if not ctx.startswith('u:'):
        raise SystemExit("no SELinux label on /%s: %r" % (p, seb))
    se_lines.append("%s %s" % (esc('/' + p if p else '.'), ctx))

open("fs_config.txt", "w").write("\n".join(fs_lines) + "\n")
open("selinux_contexts.txt", "w").write("\n".join(se_lines) + "\n")
open("vendor_dirs.txt", "w").write("\n".join(sorted(dirs)) + "\n")
print("fs_config.txt: %d entries, %d with capabilities" % (len(fs_lines), sum(1 for l in fs_lines if not l.endswith('0x0'))))
print("selinux_contexts.txt: %d entries" % len(se_lines))
print("vendor_dirs.txt: %d directories" % len(dirs))
PY

REAL_USER="${SUDO_USER:-root}"
chown "$REAL_USER" fs_config.txt selinux_contexts.txt vendor_dirs.txt 2>/dev/null || true

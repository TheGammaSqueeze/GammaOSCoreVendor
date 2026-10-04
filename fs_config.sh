#!/bin/bash
# Generate fs_config.txt from the vendor/ tree: per-inode uid, gid, mode and
# file capabilities. git stores none of these (no ownership, no xattrs, only the
# executable bit of the mode), so just like selinux_contexts.txt preserves
# SELinux labels across a clone, this file preserves ownership/mode/caps.
# e2fsdroid consumes it via -C. Must run as root to read the real metadata.
#
# Contamination guard: the extracted tree has a few files owned by the local
# build user(s) instead of root; those uids/gids are remapped to 0 and listed.
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then exec sudo -E "$0" "$@"; fi
cd "$(dirname "$0")"

# Local (non-Android) accounts that leaked in during extraction -> remap to 0.
REMAP_IDS="1000 1002"

python3 - "$REMAP_IDS" <<'PY'
import os, sys, subprocess, stat as st
remap = set(int(x) for x in sys.argv[1].split())
CAP = {n:i for i,n in enumerate(
 "chown dac_override dac_read_search fowner fsetid kill setgid setuid setpcap "
 "linux_immutable net_bind_service net_broadcast net_admin net_raw ipc_lock "
 "ipc_owner sys_module sys_rawio sys_chroot sys_ptrace sys_pacct sys_admin "
 "sys_boot sys_nice sys_resource sys_time sys_tty_config mknod lease "
 "audit_write audit_control setfcap mac_override mac_admin syslog wake_alarm "
 "block_suspend audit_read perfmon bpf checkpoint_restore".split())}

def capmask(path):
    try:
        out = subprocess.run(["getcap", path], capture_output=True, text=True).stdout.strip()
    except Exception:
        return 0
    if not out or " " not in out:
        return 0
    caps = out.split(" ",1)[1].split("=")[0]
    mask = 0
    for c in caps.split(","):
        c = c.strip()
        if c.startswith("cap_"): c = c[4:]
        if c in CAP: mask |= (1 << CAP[c])
    return mask

contaminated = []
lines = []
for dirpath, dirnames, filenames in os.walk("vendor"):
    dirnames.sort()
    entries = [dirpath] + sorted(os.path.join(dirpath, n) for n in filenames)
    for p in entries:
        lst = os.lstat(p)
        uid, gid = lst.st_uid, lst.st_gid
        if uid in remap or gid in remap:
            contaminated.append((p, uid, gid))
            if uid in remap: uid = 0
            if gid in remap: gid = 0
        mode = st.S_IMODE(lst.st_mode)
        rel = p[len("vendor"):].lstrip("/")      # "" for the vendor root
        cm = 0 if st.S_ISLNK(lst.st_mode) else capmask(p)
        lines.append("%s %d %d %04o capabilities=0x%x" % (rel, uid, gid, mode, cm))

with open("fs_config.txt","w") as f:
    f.write("\n".join(lines) + "\n")

print("fs_config.txt: %d entries" % len(lines))
caps = [l for l in lines if not l.rstrip().endswith("0x0")]
print("entries with capabilities: %d" % len(caps))
for l in caps: print("  cap:", l)
if contaminated:
    print("REMAPPED non-root owners to 0 (extraction contamination):")
    for p,u,g in contaminated: print("  %s (was %d:%d)" % (p,u,g))
PY

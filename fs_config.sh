#!/bin/bash
# Generate fs_config.txt: per-inode uid, gid, mode and file capabilities for the
# vendor tree. git stores none of these (no ownership, no xattrs, only the
# executable bit of the mode), so, like selinux_contexts.txt preserves SELinux
# labels across a clone, this file preserves ownership/mode/caps. e2fsdroid
# consumes it via -C. Must run as root to read the real metadata.
#
# Numeric uids/gids are written verbatim: the device uses Android AIDs such as
# 1000 (system), 1002 (bluetooth), 1021 (gps), 2000 (shell); these are correct
# and must NOT be remapped, even though the host may show them under local
# account names. Generate from an ownership-intact source (the device's mounted
# vendor partition, or the extracted tree), not from a git checkout.
#
# Usage: ./fs_config.sh [SOURCE_DIR]   (default: ./vendor)
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then exec sudo -E "$0" "$@"; fi
cd "$(dirname "$0")"
SRC="${1:-vendor}"

SRC="$SRC" python3 - <<'PY'
import os, subprocess, stat as st
SRC=os.environ["SRC"]
CAP={n:i for i,n in enumerate(
 "chown dac_override dac_read_search fowner fsetid kill setgid setuid setpcap "
 "linux_immutable net_bind_service net_broadcast net_admin net_raw ipc_lock "
 "ipc_owner sys_module sys_rawio sys_chroot sys_ptrace sys_pacct sys_admin "
 "sys_boot sys_nice sys_resource sys_time sys_tty_config mknod lease "
 "audit_write audit_control setfcap mac_override mac_admin syslog wake_alarm "
 "block_suspend audit_read perfmon bpf checkpoint_restore".split())}
def capmask(path):
    r=subprocess.run(["getcap",path],capture_output=True,text=True).stdout.strip()
    if not r or " " not in r: return 0
    caps=r.split(" ",1)[1].split("=")[0]; m=0
    for c in caps.split(","):
        c=c.strip()
        if c.startswith("cap_"): c=c[4:]
        if c in CAP: m|=(1<<CAP[c])
    return m
entries=[]
for dp,dns,fns in os.walk(SRC):
    dns.sort()
    for p in [dp]+sorted(os.path.join(dp,n) for n in fns):
        entries.append(p)
entries.sort()
lines=[]
for p in entries:
    lst=os.lstat(p)
    rel=os.path.relpath(p,SRC)
    rel='' if rel=='.' else rel            # vendor root -> empty name
    cm=0 if st.S_ISLNK(lst.st_mode) else capmask(p)
    lines.append("%s %d %d %04o capabilities=0x%x"%(rel,lst.st_uid,lst.st_gid,st.S_IMODE(lst.st_mode),cm))
open("fs_config.txt","w").write("\n".join(lines)+"\n")
caps=[l for l in lines if not l.endswith("0x0")]
print("fs_config.txt: %d entries, %d with capabilities"%(len(lines),len(caps)))
for l in caps: print("  ",l)
PY

#!/bin/bash
# Bake the UsbSwitch app + USB-mode init into the GammaOSCoreVendor vendor partition tree,
# then rebuild vendor.img. Run from GammaOSCoreVendor/ root. Requires sudo (vendor/ is root-owned).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"   # -> GammaOSCoreVendor
cd "$ROOT"
SRC="app/usbswitch"

echo "== staging files into vendor/ =="
install -o root -g root -m 0755 -d vendor/app vendor/app/UsbSwitch
install -o root -g root -m 0644 "$SRC/out/UsbSwitch.apk"                 vendor/app/UsbSwitch/UsbSwitch.apk
install -o root -g root -m 0755 "$SRC/vendor_files/bin/gammaos_usbmode.sh" vendor/bin/gammaos_usbmode.sh
install -o root -g root -m 0644 "$SRC/vendor_files/etc/init/init.gammaos_usb.rc" vendor/etc/init/init.gammaos_usb.rc

echo "== adding SELinux file contexts (idempotent) =="
add_ctx() { grep -qF -- "$1" selinux_contexts.txt || echo "$1" >> selinux_contexts.txt; }
add_ctx '/app/UsbSwitch u:object_r:vendor_app_file:s0'
add_ctx '/app/UsbSwitch/UsbSwitch\.apk u:object_r:vendor_app_file:s0'
add_ctx '/bin/gammaos_usbmode\.sh u:object_r:vendor_file:s0'
add_ctx '/etc/init/init\.gammaos_usb\.rc u:object_r:vendor_configs_file:s0'

echo "== neutralizing inert debugfs mode-host in init.rk3576-4d.rc =="
cat > vendor/etc/init/init.rk3576-4d.rc <<'EOF'
# GammaOS: the debugfs dwc3 "mode host" force below is INERT on RK3576 - the OTG port
# (23000000.usb) uses usb-role-switch, so the Type-C TCPM (HUSB311) owns the data role and the
# debugfs write is ignored. The GammaOS USB switch (init.gammaos_usb.rc + gammaos_usbmode.sh)
# drives the role via the authoritative /sys/class/typec/port0/port_type instead. Kept here,
# neutralized, so the old misleading force-host does not mask the real mechanism.
#on property:sys.boot_completed=1
#    chmod 0666 /sys/kernel/debug/usb/23000000.usb/mode
#    write /sys/kernel/debug/usb/23000000.usb/mode host
EOF
chown root:root vendor/etc/init/init.rk3576-4d.rc
chmod 0644 vendor/etc/init/init.rk3576-4d.rc

echo "== rebuilding vendor.img =="
bash build.sh

echo "== done. vendor.img: =="
ls -l vendor.img

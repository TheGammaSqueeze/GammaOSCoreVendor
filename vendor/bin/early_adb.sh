#!/vendor/bin/sh
# GammaOS: bring USB adb up without system_server (debuggable builds).
#
# This vendor uses the USB gadget HAL (sys.usb.configfs=2), so nothing starts adbd
# or binds the gadget until system_server's UsbDeviceManager asks the HAL to, and
# on a first boot that is a minute or more away (odsign/odrefresh compile the boot
# classpath inside post-fs-data; a stalled display stack adds more). Property
# triggers ("on property:apexd.status=...") are no help: init enables them only
# after the boot stage. So this runs as a service from post-fs and does the work
# itself: it waits for the adbd APEX to be activated and for the gadget pieces
# init.qcom.usb.rc sets up at post-fs-data, asks init to start adbd (init queues
# the start until the APEX configs are loaded, which is right before the odsign
# wait), then binds only the adb function once adbd reports its endpoints ready.
# When system_server comes up the gadget HAL reconfigures the gadget exactly as
# before: it unlinks every "function*" entry and applies the normal set, so adb
# drops for a moment and returns with MTP and the rest when selected.

TAG=early_adb
G=/config/usb_gadget/g1
klog() { echo "$TAG: $*" > /dev/kmsg 2>/dev/null; }
up() { cut -d' ' -f1 /proc/uptime; }

[ "$(getprop ro.debuggable)" = "1" ] || exit 0
setprop vendor.gammaos.early_adb armed

# The gadget and the adb FunctionFS mount: init.qcom.usb.rc creates them at
# post-fs-data, but that block runs after the system's post-fs-data, which on a
# first boot waits a minute for odsign. Set up the pieces adbd needs here; the
# later mkdirs and mounts of the same things then just fail harmlessly.
grep -q ' /config ' /proc/mounts || mount -t configfs none /config
mkdir -p "$G/strings/0x409" "$G/configs/b.1/strings/0x409" "$G/functions/ffs.adb"
echo 0x0200 > "$G/bcdUSB"
echo "$(getprop ro.serialno)" > "$G/strings/0x409/serialnumber"
echo "$(getprop ro.product.manufacturer)" > "$G/strings/0x409/manufacturer"
echo "$(getprop ro.product.model)" > "$G/strings/0x409/product"
echo 900 > "$G/configs/b.1/MaxPower"
mkdir -p /dev/usb-ffs/adb
chown shell:system /dev/usb-ffs /dev/usb-ffs/adb 2>/dev/null
chmod 0770 /dev/usb-ffs/adb
grep -q ' /dev/usb-ffs/adb ' /proc/mounts || mount -t functionfs -o uid=2000,gid=1000,rmode=0770,fmode=0660 adb /dev/usb-ffs/adb

# the adbd APEX (apexd activates them in post-fs-data; init queues the start
# until the APEX configs are loaded, which is before the odsign wait)
i=0
while [ $i -lt 600 ]; do
    st=$(getprop apexd.status)
    if [ "$st" = "activated" ] || [ "$st" = "ready" ]; then
        break
    fi
    sleep 0.1
    i=$((i + 1))
done
if [ $i -ge 600 ]; then
    klog "gave up at $(up)s: apexd.status=$(getprop apexd.status)"
    exit 0
fi

klog "starting adbd at $(up)s (apexd.status=$(getprop apexd.status))"
setprop ctl.start adbd

i=0
while [ "$(getprop sys.usb.ffs.ready)" != "1" ] && [ $i -lt 300 ]; do
    sleep 0.1
    i=$((i + 1))
done
if [ "$(getprop sys.usb.ffs.ready)" != "1" ]; then
    klog "adbd did not open its endpoints within 30 s (init.svc.adbd=$(getprop init.svc.adbd)); gadget left alone"
    exit 0
fi

ctrl=$(getprop vendor.usb.controller)
[ -n "$ctrl" ] || ctrl=4e00000.dwc3
echo none > "$G/UDC" 2>/dev/null
echo 0x18d1 > "$G/idVendor"
echo 0x4ee7 > "$G/idProduct"
echo adb > "$G/configs/b.1/strings/0x409/configuration"
# "function0": the gadget HAL only unlinks entries whose name contains "function"
# before applying its own set; any other name survives and breaks its own link.
# Plain ln -s: toybox's ln -f renames the old entry first and configfs refuses
# renames, so the link was never made and the UDC bind failed with no function.
rm -f "$G/configs/b.1/function0"
if ! err=$(ln -s "$G/functions/ffs.adb" "$G/configs/b.1/function0" 2>&1); then
    klog "function link failed: $err"
    exit 0
fi
if ! err=$(echo "$ctrl" > "$G/UDC" 2>&1); then
    klog "UDC bind failed: $err"
    exit 0
fi
setprop vendor.gammaos.early_adb done
klog "adb bound to $ctrl at $(up)s"

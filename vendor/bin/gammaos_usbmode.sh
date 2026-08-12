#!/system/bin/sh
# GammaOS USB mode - GKD ATOM (RK3576, HUSB311 Type-C TCPC). Reads persist.gammaos.usb.mode.
#
# Applied live (real time), no reboot required to change the port role:
#   normal = USB device (charging, file transfer/MTP, ADB): port_type=sink with the USB gadget
#            running. Switching back from otg tears down any host session instantly.
#   otg    = USB host (keyboards, mice, gamepads, drives): a host-preferring dual-role port
#            (port_type=dual, preferred_role=source) with the USB gadget stopped so it does not
#            pin the port as a device. This mirrors the ROCKNIX host state, so a newly plugged or
#            replugged accessory hosts without a reboot.
#
# Hardware note: the Type-C TCPM will not re-negotiate an ALREADY-settled cable, so an accessory
# that was attached at the moment of switching to otg may need a quick unplug/replug (or a restart)
# to be hosted. NEVER unbind/bind the HUSB311 TCPC to force it - that can hang the SoC.
# port_type + preferred_role + the gadget service are the safe knobs.
PORT=/sys/class/typec/port0
GADGET=vendor.usb_gadget_default
case "$(getprop persist.gammaos.usb.mode)" in
  otg)
    setprop ctl.stop "$GADGET"
    echo source > "$PORT/preferred_role" 2>/dev/null
    echo dual   > "$PORT/port_type"      2>/dev/null
    ;;
  *)
    echo sink > "$PORT/preferred_role" 2>/dev/null
    echo sink > "$PORT/port_type"      2>/dev/null
    setprop ctl.start "$GADGET"
    ;;
esac
log -t gammaos_usbmode "USB mode applied: $(getprop persist.gammaos.usb.mode)"

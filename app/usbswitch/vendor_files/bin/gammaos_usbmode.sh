#!/system/bin/sh
# GammaOS USB mode - GKD ATOM (RK3576, HUSB311 Type-C TCPC). Reads persist.gammaos.usb.mode.
#   normal = USB device (charging, file transfer/MTP, ADB): port_type=sink.
#   otg    = USB host (keyboards, mice, gamepads, drives): port_type=dual. Reboot into otg with the
#            accessory attached and the boot-time Type-C negotiation hosts it. A live switch cannot
#            re-host an already-settled cable, so the app reboots to enter OTG host.
# port_type is the authoritative, SAFE knob. Do NOT stop the USB gadget here: killing
# vendor.usb_gadget_default early in boot removes the IUsbGadget HAL and crashes the system_server
# USB manager -> bootloop (and also kills USB adb). NEVER unbind/bind the HUSB311 TCPC (hangs SoC).
PORT=/sys/class/typec/port0
case "$(getprop persist.gammaos.usb.mode)" in
  otg) echo dual > "$PORT/port_type" 2>/dev/null ;;
  *)   echo sink > "$PORT/port_type" 2>/dev/null ;;
esac
log -t gammaos_usbmode "USB mode applied: $(getprop persist.gammaos.usb.mode)"

#!/vendor/bin/sh
# GammaOS RP Duo Lite: keep the charger's input limit at the Type-C advertised current.
#
# With a charger attached (no USB host), the USB gadget stack votes the "unconfigured
# device" limit of 100 mA on the PMI632's USB input (USB_PSY voter). On a normal Android
# boot the USB framework later reconfigures the gadget and the vote is lifted; the nano
# boot never does that, so the limit stayed at 100 mA and the battery discharged on a
# 45 W charger. The BC1.2 result on this port is "floating", which the driver treats as
# an SDP, so it honours that vote. This loop re-votes the input limit to what the
# Type-C source advertises (1.5 A for Rp-1.5A, 3 A for Rp-3A) whenever the vote sits
# below it; the hardware AICL still limits the input to what the adapter and cable sustain.
# Sources advertising only default current and PC ports (an enumerated gadget) are
# left alone.
USB=/sys/class/power_supply/usb
SMB=""
while [ -z "$SMB" ]; do
    for d in /sys/bus/iio/devices/iio:device*; do
        case "$(cat $d/name 2>/dev/null)" in *smb5*) [ -e $d/in_index_usb_typec_mode_input ] && SMB=$d ;; esac
    done
    [ -z "$SMB" ] && sleep 5
done
while true; do
    if [ "$(cat $USB/online 2>/dev/null)" = "1" ]; then
        mode=$(cat $SMB/in_index_usb_typec_mode_input 2>/dev/null)
        want=0
        case "$mode" in
            7) want=1500000 ;;   # QTI_POWER_SUPPLY_TYPEC_SOURCE_MEDIUM
            8) want=3000000 ;;   # QTI_POWER_SUPPLY_TYPEC_SOURCE_HIGH
        esac
        if [ "$want" != "0" ]; then
            cur=$(cat $USB/input_current_limit 2>/dev/null)
            case "$cur" in -*|"") cur=0 ;; esac
            if [ "$cur" -lt "$want" ] && [ "$(cat /sys/class/udc/*/state 2>/dev/null | head -1)" != "configured" ]; then
                echo $want > $USB/input_current_limit
            fi
        fi
    fi
    sleep 3
done

#!/vendor/bin/sh
# GammaOS: publish each panel's backlight range for split brightness. The top
# AMOLED's max_brightness is 8191, so a fixed 255 would cap it at 3 percent.
# The DSI backlights register with msm_drm, normally before post-fs; wait a
# little in case a panel is slow.
set_max() {
    slot=$1
    f=/sys/class/backlight/$2/max_brightness
    i=0
    while [ ! -r $f ] && [ $i -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
    if [ -r $f ]; then
        setprop persist.gammaos.multidisplay.split_brightness.$slot.max "$(cat $f)"
    else
        echo "gammaos_backlight_props: no $f" > /dev/kmsg
    fi
}
set_max d0 panel0-backlight
set_max d1 panel1-backlight

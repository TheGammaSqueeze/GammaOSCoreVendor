#!/system/bin/sh

# BFI
setprop persist.gammaos.bfi.black_floor 0.01
setprop persist.gammaos.bfi.debug 0
setprop persist.gammaos.bfi.duty_percent 50
setprop persist.gammaos.bfi.flip.auto_dip 0
setprop persist.gammaos.bfi.flip.contrast 1.0
setprop persist.gammaos.bfi.flip.contrast.enable 1
setprop persist.gammaos.bfi.flip.contrast_pivot 0.5
setprop persist.gammaos.bfi.flip.gamma 0.4
setprop persist.gammaos.bfi.flip.guard_frames 0
setprop persist.gammaos.bfi.flip.in.end_dim 0.30
setprop persist.gammaos.bfi.flip.in.start_dim 0.30
setprop persist.gammaos.bfi.flip.in_frames 1
setprop persist.gammaos.bfi.flip.out.end_dim 0.30
setprop persist.gammaos.bfi.flip.out.start_dim 0.30
setprop persist.gammaos.bfi.flip.out_frames 1
setprop persist.gammaos.bfi.flip.rgb.b 1.0
setprop persist.gammaos.bfi.flip.rgb.g 1
setprop persist.gammaos.bfi.flip.rgb.r 1
setprop persist.gammaos.bfi.flip.sat 1.0
setprop persist.gammaos.bfi.flip.window 0
setprop persist.gammaos.bfi.flip.window_dim 1.0
setprop persist.gammaos.bfi.flip.zero_eps 0
setprop persist.gammaos.bfi.force_content_60 0
setprop persist.gammaos.bfi.mode ctm
setprop persist.gammaos.bfi.pattern 10
setprop persist.gammaos.bfi.polarity_period_ms 30000
setprop persist.gammaos.bfi.seam_brightness 0.6
setprop persist.gammaos.bfi.seam_follow_brightness 0.6
setprop persist.gammaos.bfi.seam_gamma 0.1
setprop persist.gammaos.bfi.seam_pre_dim 0.1
setprop persist.gammaos.bfi.seam_ramp2 0.45
setprop persist.gammaos.bfi.subframe.cadence_min 0.5
setprop persist.gammaos.bfi.subframe.debug 0
setprop persist.gammaos.bfi.subframe.duty 0.45
setprop persist.gammaos.bfi.subframe.enable 0
setprop persist.gammaos.bfi.subframe.phase_step 0.5

setprop persist.gammaos.ext.primary 1

mkdir -p /data/GammaPad

su -c 'cat > /data/GammaPad/MAPPINGS << "EOF"
KEY_F10 KEY_ALL_APPLICATIONS
KEY_BACK KEY_BACK
BTN_GAMEPAD BTN_GAMEPAD
BTN_EAST BTN_EAST
BTN_C BTN_C
BTN_NORTH BTN_NORTH
BTN_WEST BTN_WEST
BTN_Z BTN_Z
BTN_TL BTN_TL
BTN_TR BTN_TR
BTN_TL2 BTN_TL2
BTN_TR2 BTN_TR2
BTN_SELECT BTN_SELECT
BTN_START BTN_START
BTN_MODE BTN_MODE
BTN_THUMBL BTN_THUMBL
BTN_THUMBR BTN_THUMBR
BTN_DPAD_UP BTN_DPAD_UP
BTN_DPAD_DOWN BTN_DPAD_DOWN
BTN_DPAD_LEFT BTN_DPAD_LEFT
BTN_DPAD_RIGHT BTN_DPAD_RIGHT
EOF'

setprop persist.gammaos.ext.force_mirror 1

mkdir -p /sdcard/GammaEQ
cp /vendor/etc/Sparkle-Cube.txt /sdcard/GammaEQ/Sparkle-Cube.txt

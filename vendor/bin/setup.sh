#!/system/bin/sh

# GammaEQ — Sparkle-477V (Speakers)
#
# This script:
#   - Enables GammaEQ on speakers only
#   - Applies the Crystalizer, LBP, Mid Protector, PEQ1, PEQ2 and Stereo Widener
#   - Uses the exact preset values provided (no recalculation)

# ===== Master gating & routing (enable GammaEQ on speakers only) =====
setprop persist.sys.gammaeq.enable 1            # Turn GammaEQ processing ON
setprop persist.sys.gammaeq.spk_only 1          # Apply only to speaker route
setprop persist.sys.gammaeq.force 0             # Do not force EQ on other routes

# ===== Global headroom / makeup =====
setprop persist.sys.gammaeq.preamp_db  -0.13636315  # Small safety cut to avoid clipping
setprop persist.sys.gammaeq.postgain_db 0           # No post gain

# ------------------------------------------------------------
# Crystalizer section
# ------------------------------------------------------------

# Enable/disable Crystalizer block
setprop persist.sys.spk.cryst 1                 # 0 = OFF, 1 = ON

# Crystalizer shaping parameters
setprop persist.sys.spk.cryst.amount 4.0        # Amount of HF "enhancement"
setprop persist.sys.spk.cryst.mix 0.25          # Wet/dry mix
setprop persist.sys.spk.cryst.hz 11500          # Corner frequency for HF emphasis
setprop persist.sys.spk.cryst.pregain_db -8     # Pre-gain into the block (dB)
setprop persist.sys.spk.cryst.postgain_db 9.363636  # Post-gain out of the block (dB)
setprop persist.sys.spk.cryst.pre 0.40          # Internal pre-emphasis factor
setprop persist.sys.spk.cryst.fc 11500          # Internal cutoff / center freq
setprop persist.sys.spk.cryst.limit 0.30        # Internal limiter threshold

# Nudge Crystalizer sequence so AudioFlinger picks up changes
setprop persist.sys.spk.cryst.seq $(( $(getprop persist.sys.spk.cryst.seq 0) + 1 ))

# ------------------------------------------------------------
# Low-Band Protector (LBP) — protects bass from over-excursion
# ------------------------------------------------------------

setprop persist.sys.spk.lbp 1                   # Enable Low-Band Protector
setprop persist.sys.spk.lbp.fc 160              # Crossover frequency (Hz)
setprop persist.sys.spk.lbp.thr 0.6934932       # Threshold (linear)
setprop persist.sys.spk.lbp.atk 4               # Attack time (ms)
setprop persist.sys.spk.lbp.rel 110             # Release time (ms)

setprop persist.sys.spk.lbp.seq $(( $(getprop persist.sys.spk.lbp.seq 0) + 1 ))

# ------------------------------------------------------------
# Mid Protector — keeps mids under control
# ------------------------------------------------------------

setprop persist.sys.spk.mp 1                    # Enable Mid Protector
setprop persist.sys.spk.mp.hpf 220              # High-pass edge (Hz)
setprop persist.sys.spk.mp.lpf 5800             # Low-pass edge (Hz)
setprop persist.sys.spk.mp.thr 0.92             # Threshold (linear)
setprop persist.sys.spk.mp.atk 2                # Attack time (ms)
setprop persist.sys.spk.mp.rel 120              # Release time (ms)

setprop persist.sys.spk.mp.seq $(( $(getprop persist.sys.spk.mp.seq 0) + 1 ))

# ------------------------------------------------------------
# PEQ1 — main clarity / tilt filter
# ------------------------------------------------------------

setprop persist.sys.spk.peq 1                   # Enable PEQ1 block
setprop persist.sys.spk.peq.b0 0.91477275       # Bi-quad b0 coefficient
setprop persist.sys.spk.peq.b1 -1.9848485       # Bi-quad b1 coefficient
setprop persist.sys.spk.peq.b2 0.60             # Bi-quad b2 coefficient
setprop persist.sys.spk.peq.a1 0                # Bi-quad a1 coefficient
setprop persist.sys.spk.peq.a2 0                # Bi-quad a2 coefficient
setprop persist.sys.spk.peq.pregain 1.0         # Linear pregain
setprop persist.sys.spk.peq.keepheadroom 1      # Keep headroom for this filter
setprop persist.sys.spk.peq.limit 0             # Limiting disabled here

setprop persist.sys.spk.peq.seq $(( $(getprop persist.sys.spk.peq.seq 0) + 1 ))

# ------------------------------------------------------------
# PEQ2 — warmth / body
# ------------------------------------------------------------

setprop persist.sys.spk.peq2 1                  # Enable PEQ2 block
setprop persist.sys.spk.peq2.b0 0.10795455      # Bi-quad b0 coefficient
setprop persist.sys.spk.peq2.b1 -2.090909       # Bi-quad b1 coefficient
setprop persist.sys.spk.peq2.b2 0.60            # Bi-quad b2 coefficient
setprop persist.sys.spk.peq2.a1 0               # Bi-quad a1 coefficient
setprop persist.sys.spk.peq2.a2 0               # Bi-quad a2 coefficient

setprop persist.sys.spk.peq2.seq $(( $(getprop persist.sys.spk.peq2.seq 0) + 1 ))

# ------------------------------------------------------------
# Stereo Widener — stronger width enhancement
# ------------------------------------------------------------

setprop persist.sys.spk.wide 1                  # Enable stereo wide block
setprop persist.sys.spk.wide.mix 0.91780823     # Wet/dry mix
setprop persist.sys.spk.wide.hpf 5500           # High-pass for widening (Hz)
setprop persist.sys.spk.wide.amount 2.0         # Overall widening amount
setprop persist.sys.spk.wide.pre 11.856165      # Internal pre factor
setprop persist.sys.spk.wide.limit 0.30907536   # Internal limiter threshold
setprop persist.sys.spk.wide.fc 16000.0         # Internal cutoff / center freq

setprop persist.sys.spk.wide.seq $(( $(getprop persist.sys.spk.wide.seq 0) + 1 ))

# ------------------------------------------------------------
# Route flag — make sure speakers are the active GammaEQ route
# ------------------------------------------------------------

setprop sys.gammaeq.route.spk 1                 # 1 = use speaker route for GammaEQ

# BFI
setprop persist.gammaos.bfi.black_floor 0.01
setprop persist.gammaos.bfi.debug 0
setprop persist.gammaos.bfi.duty_percent 50
setprop persist.gammaos.bfi.flip.auto_dip 0
setprop persist.gammaos.bfi.flip.contrast 1.0
setprop persist.gammaos.bfi.flip.contrast.enable 1
setprop persist.gammaos.bfi.flip.contrast_pivot 0.5
setprop persist.gammaos.bfi.flip.gamma 0.75
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

sed -i 's/vrr_runloop_enable = "false"/vrr_runloop_enable = "true"/'  /sdcard/Android/data/com.retroarch.aarch64/files/retroarch.cfg
setprop persist.gammaos.ext.force_mirror 1

mkdir -p /sdcard/GammaEQ
cp /vendor/etc/Sparkle-477M.txt /sdcard/GammaEQ/Sparkle-477M.txt

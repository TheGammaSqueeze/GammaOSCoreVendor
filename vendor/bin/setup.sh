#!/system/bin/sh

# GammaEQ — Sparkle (Speakers) with boosted warmth (PEQ2 b0 = 2.9922945)
#
# This script:
#   - Enables GammaEQ on speakers only
#   - Applies the Crystalizer, LBP, Mid Protector, PEQ1, PEQ2 and Stereo Widener
#   - Uses your exact coefficient / parameter values (no recalculation)

# ===== Master gating & routing (enable GammaEQ on speakers only) =====
setprop persist.sys.gammaeq.enable 1           # Turn GammaEQ processing ON
setprop persist.sys.gammaeq.spk_only 1         # Apply only to speaker route
setprop persist.sys.gammaeq.force 0            # Do not force EQ on other routes

# ===== Global headroom / makeup =====
setprop persist.sys.gammaeq.preamp_db -1.0
setprop persist.sys.gammaeq.postgain_db 0      # No post gain

# ------------------------------------------------------------
# Crystalizer section (enabled by default)
# ------------------------------------------------------------

# Enable/disable Crystalizer block
setprop persist.sys.spk.cryst 1                # 0 = OFF, 1 = ON

# Crystalizer shaping parameters
setprop persist.sys.spk.cryst.amount 3.630137
setprop persist.sys.spk.cryst.mix 0.25         # Wet/dry mix
setprop persist.sys.spk.cryst.hz 11500         # Corner frequency for HF emphasis
setprop persist.sys.spk.cryst.pregain_db -8    # Pre-gain into the block (dB)
setprop persist.sys.spk.cryst.postgain_db 9.363636 # Post-gain out of the block (dB)
setprop persist.sys.spk.cryst.pre 0.40         # Internal pre-emphasis factor
setprop persist.sys.spk.cryst.fc 11500         # Internal cutoff / center freq
setprop persist.sys.spk.cryst.limit 0.30       # Internal limiter threshold

# Nudge Crystalizer sequence so AudioFlinger picks up changes
setprop persist.sys.spk.cryst.seq $(( $(getprop persist.sys.spk.cryst.seq 0) + 1 ))

# ------------------------------------------------------------
# Low-Band Protector (LBP) — protects bass from over-excursion
# ------------------------------------------------------------

setprop persist.sys.spk.lbp 1                  # Enable Low-Band Protector
setprop persist.sys.spk.lbp.fc 160             # Crossover frequency (Hz)
setprop persist.sys.spk.lbp.thr 0.6934932      # Threshold (linear)
setprop persist.sys.spk.lbp.atk 4              # Attack time (ms)
setprop persist.sys.spk.lbp.rel 110            # Release time (ms)

setprop persist.sys.spk.lbp.seq $(( $(getprop persist.sys.spk.lbp.seq 0) + 1 ))

# ------------------------------------------------------------
# Mid Protector — keeps mids under control
# ------------------------------------------------------------

setprop persist.sys.spk.mp 1                   # Enable Mid Protector
setprop persist.sys.spk.mp.hpf 220             # High-pass edge (Hz)
setprop persist.sys.spk.mp.lpf 5800            # Low-pass edge (Hz)
setprop persist.sys.spk.mp.thr 0.92            # Threshold (linear)
setprop persist.sys.spk.mp.atk 2               # Attack time (ms)
setprop persist.sys.spk.mp.rel 120             # Release time (ms)

setprop persist.sys.spk.mp.seq $(( $(getprop persist.sys.spk.mp.seq 0) + 1 ))

# ------------------------------------------------------------
# PEQ1 — main clarity / tilt filter
# ------------------------------------------------------------

setprop persist.sys.spk.peq 1                  # Enable PEQ1 block
setprop persist.sys.spk.peq.b0 1.30
setprop persist.sys.spk.peq.b1 -1.40
setprop persist.sys.spk.peq.b2 0.57222223
setprop persist.sys.spk.peq.a1 0               # Bi-quad a1 coefficient
setprop persist.sys.spk.peq.a2 0               # Bi-quad a2 coefficient
setprop persist.sys.spk.peq.pregain 1.0        # Linear pregain
setprop persist.sys.spk.peq.keepheadroom 1     # Keep headroom for this filter
setprop persist.sys.spk.peq.limit 0            # Limiting disabled here

setprop persist.sys.spk.peq.seq $(( $(getprop persist.sys.spk.peq.seq 0) + 1 ))

# ------------------------------------------------------------
# PEQ2 — warmth / body (boosted b0 = 2.9922945)
# ------------------------------------------------------------

setprop persist.sys.spk.peq2 1                 # Enable PEQ2 block
setprop persist.sys.spk.peq2.b0 2.9922945
setprop persist.sys.spk.peq2.b1 -0.31506848
setprop persist.sys.spk.peq2.b2 0.60
setprop persist.sys.spk.peq2.a1 0              # Bi-quad a1 coefficient
setprop persist.sys.spk.peq2.a2 0              # Bi-quad a2 coefficient

setprop persist.sys.spk.peq2.seq $(( $(getprop persist.sys.spk.peq2.seq 0) + 1 ))

# ------------------------------------------------------------
# Stereo Widener — stronger width enhancement
# ------------------------------------------------------------

setprop persist.sys.spk.wide 1                 # Enable stereo wide block
setprop persist.sys.spk.wide.mix 0.91780823    # Wet/dry mix
setprop persist.sys.spk.wide.hpf 5500          # High-pass for widening (Hz)
setprop persist.sys.spk.wide.amount 1.6232877
setprop persist.sys.spk.wide.pre 11.856165
setprop persist.sys.spk.wide.limit 0.30907536
setprop persist.sys.spk.wide.fc 16000.0

setprop persist.sys.spk.wide.seq $(( $(getprop persist.sys.spk.wide.seq 0) + 1 ))

# ------------------------------------------------------------
# Route flag — make sure speakers are the active GammaEQ route
# ------------------------------------------------------------

setprop sys.gammaeq.route.spk 1                # 1 = use speaker route for GammaEQ

mkdir -p /sdcard/GammaEQ
cp /vendor/etc/Sparkle-MangmiAirX.txt /sdcard/GammaEQ/

settings put global window_animation_scale 0
settings put global transition_animation_scale 0
settings put global animator_duration_scale 0

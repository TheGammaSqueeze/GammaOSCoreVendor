#!/system/bin/sh

# GammaEQ — Sparkle (Speakers) with boosted warmth (PEQ2 b0 = 2.6)
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
setprop persist.sys.gammaeq.preamp_db  -1.0    # Small safety cut to avoid clipping
setprop persist.sys.gammaeq.postgain_db 0      # No post gain

# ------------------------------------------------------------
# Crystalizer section (configured but disabled by default)
# ------------------------------------------------------------

# Enable/disable Crystalizer block
setprop persist.sys.spk.cryst 0                # 0 = OFF, 1 = ON

# Crystalizer shaping parameters
setprop persist.sys.spk.cryst.amount 0.40      # Amount of HF "enhancement"
setprop persist.sys.spk.cryst.mix 0.25         # Wet/dry mix
setprop persist.sys.spk.cryst.hz 11500         # Corner frequency for HF emphasis
setprop persist.sys.spk.cryst.pregain_db -8    # Pre-gain into the block (dB)
setprop persist.sys.spk.cryst.postgain_db 0    # Post-gain out of the block (dB)
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
setprop persist.sys.spk.lbp.thr 0.24           # Threshold (linear, ~-12 dB)
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
setprop persist.sys.spk.peq.b0 1.30            # Bi-quad b0 coefficient
setprop persist.sys.spk.peq.b1 -1.40           # Bi-quad b1 coefficient
setprop persist.sys.spk.peq.b2 0.60            # Bi-quad b2 coefficient
setprop persist.sys.spk.peq.a1 0               # Bi-quad a1 coefficient
setprop persist.sys.spk.peq.a2 0               # Bi-quad a2 coefficient
setprop persist.sys.spk.peq.pregain 1.0        # Linear pregain
setprop persist.sys.spk.peq.keepheadroom 1     # Keep headroom for this filter
setprop persist.sys.spk.peq.limit 0            # Limiting disabled here

setprop persist.sys.spk.peq.seq $(( $(getprop persist.sys.spk.peq.seq 0) + 1 ))

# ------------------------------------------------------------
# PEQ2 — warmth / body (boosted b0 = 2.6)
# ------------------------------------------------------------

setprop persist.sys.spk.peq2 1                 # Enable PEQ2 block
setprop persist.sys.spk.peq2.b0 2.6            # Bi-quad b0 coefficient (extra warmth)
setprop persist.sys.spk.peq2.b1 -0.95          # Bi-quad b1 coefficient
setprop persist.sys.spk.peq2.b2 0.60           # Bi-quad b2 coefficient
setprop persist.sys.spk.peq2.a1 0              # Bi-quad a1 coefficient
setprop persist.sys.spk.peq2.a2 0              # Bi-quad a2 coefficient

setprop persist.sys.spk.peq2.seq $(( $(getprop persist.sys.spk.peq2.seq 0) + 1 ))

# ------------------------------------------------------------
# Stereo Widener — subtle width enhancement
# ------------------------------------------------------------

setprop persist.sys.spk.wide 1                 # Enable stereo wide block
setprop persist.sys.spk.wide.mix 0.25          # Wet/dry mix (0 = off, 1 = fully wide)
setprop persist.sys.spk.wide.hpf 5500          # High-pass for widening (Hz)
setprop persist.sys.spk.wide.amount 0.75       # Overall widening amount

setprop persist.sys.spk.wide.seq $(( $(getprop persist.sys.spk.wide.seq 0) + 1 ))

# ------------------------------------------------------------
# Route flag — make sure speakers are the active GammaEQ route
# ------------------------------------------------------------

setprop sys.gammaeq.route.spk 1                # 1 = use speaker route for GammaEQ


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

#!/vendor/bin/sh
# GammaOS RP Duo Lite vendor provisioning, run by the system setup.sh on first boot.

# GammaEQ preset for the app. The archive is rooted at GammaEQ/ and extracted into
# /sdcard (not an archive carrying sdcard/ itself: toybox tar then tries to restore the
# storage root's mtime, which FUSE refuses, and the step reports errors).
tar -xvf /vendor/etc/GammaEQ.tar.gz -C /sdcard

# Speaker tuning, the same values as the preset and the build.prop defaults.
setprop persist.sys.gammaeq.spk_only 1
setprop persist.sys.gammaeq.force 0
setprop persist.sys.gammaeq.preamp_db -5.8146496
setprop persist.sys.gammaeq.postgain_db 0
setprop persist.sys.spk.cryst 1
setprop persist.sys.spk.cryst.amount 4.0
setprop persist.sys.spk.cryst.mix 1.0
setprop persist.sys.spk.cryst.hz 11500
setprop persist.sys.spk.cryst.pregain_db -0.65995
setprop persist.sys.spk.cryst.postgain_db 12.0
setprop persist.sys.spk.cryst.pre 0.40
setprop persist.sys.spk.cryst.fc 11500
setprop persist.sys.spk.cryst.limit 1.0
setprop persist.sys.spk.lbp 1
setprop persist.sys.spk.lbp.fc 160
setprop persist.sys.spk.lbp.thr 0.6934932
setprop persist.sys.spk.lbp.atk 4
setprop persist.sys.spk.lbp.rel 110
setprop persist.sys.spk.mp 1
setprop persist.sys.spk.mp.hpf 220
setprop persist.sys.spk.mp.lpf 5800
setprop persist.sys.spk.mp.thr 0.92
setprop persist.sys.spk.mp.atk 2
setprop persist.sys.spk.mp.rel 120
setprop persist.sys.spk.peq 1
setprop persist.sys.spk.peq.b0 0.61841464
setprop persist.sys.spk.peq.b1 -1.378114
setprop persist.sys.spk.peq.b2 0.5056768
setprop persist.sys.spk.peq.a1 0
setprop persist.sys.spk.peq.a2 0
setprop persist.sys.spk.peq.pregain 1.0
setprop persist.sys.spk.peq.keepheadroom 1
setprop persist.sys.spk.peq.limit 0
setprop persist.sys.spk.peq2 1
setprop persist.sys.spk.peq2.b0 1.3215681
setprop persist.sys.spk.peq2.b1 0.4335251
setprop persist.sys.spk.peq2.b2 0.567357
setprop persist.sys.spk.peq2.a1 0
setprop persist.sys.spk.peq2.a2 0
setprop persist.sys.spk.wide 1
setprop persist.sys.spk.wide.mix 1.0
setprop persist.sys.spk.wide.hpf 5500
setprop persist.sys.spk.wide.amount 2.0
setprop persist.sys.spk.wide.pre 0.75074387
setprop persist.sys.spk.wide.limit 1.0
setprop persist.sys.gammaeq.enable 1

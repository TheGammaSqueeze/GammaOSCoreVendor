#!/system/bin/sh
# GammaOS vendor setup hook - GKD 350H Ultra.
#
# Invoked by /system/bin/setup.sh (the gammaos first-run setup script) near its
# end, while the nano setup wizard is running.
#
# Why this exists: right after setup, nano's finishSetupWizard() runs several
# blocking calls (settings put / ime reset / locksettings clear) on its render
# thread. That stall starves nano's output AudioTrack, AudioFlinger tears it down,
# and nano never re-creates it - so all nano audio (nav SFX + menu music) stays
# silent until nano is restarted.
#
# The wedge happens AFTER this script returns. We cannot just fork a background
# child here: /system/bin/setup.sh runs as a oneshot init service, and when it
# exits init kills its whole cgroup (a setsid child does not escape cgroup v2), so
# the child dies before finishSetupWizard runs. Instead we arm a standalone init
# service (its own cgroup, survives) that runs the watchdog below.

TAG=gammaos-vendor-setup

watchdog() {
    # Wait for the nano wizard to complete: finishSetupWizard() sets
    # sys.gammaos.nano.setup_active=0 and persist.gammaos.nano.setup_done=1, and
    # that transition is exactly when the audio track gets wedged. Bounded ~4 min.
    i=0
    while [ "$i" -lt 120 ]; do
        [ "$(getprop sys.gammaos.nano.setup_active)" != "1" ] && \
        [ "$(getprop persist.gammaos.nano.setup_done)" = "1" ] && break
        sleep 2
        i=$((i + 1))
    done
    # Let finishSetupWizard's blocking calls fully settle before acting.
    sleep 3

    # Unwedge: restart the audio server (clears any stuck AudioFlinger state) then
    # gammaos-nano (which re-creates its audio on startup). Keep trying until nano
    # comes back with a fresh pid, so a single mistimed attempt still recovers.
    n=0
    while [ "$n" -lt 6 ]; do
        old="$(pgrep -f gammaos-nano | head -n 1)"
        log -t "$TAG" "unwedging nano audio (attempt $n, nano pid $old)"
        setprop ctl.restart audioserver
        sleep 2
        setprop ctl.restart gammaos-nano
        sleep 8
        new="$(pgrep -f gammaos-nano | head -n 1)"
        if [ -n "$new" ] && [ "$new" != "$old" ]; then
            log -t "$TAG" "nano restarted ($old -> $new); audio re-armed"
            break
        fi
        n=$((n + 1))
        sleep 3
    done
    log -t "$TAG" "unwedge watchdog finished"
}

# Run as the standalone init service (own cgroup) that survives setup.sh exiting.
if [ "$1" = "watchdog" ]; then
    watchdog
    exit 0
fi

# Called from /system/bin/setup.sh during setup: arm the watchdog service. init
# starts gammaos_audiofix on this property edge (see init.gammaos_audiofix.rc).
log -t "$TAG" "arming nano-audio unwedge watchdog service"
setprop sys.gammaos.audiofix_arm 1
exit 0

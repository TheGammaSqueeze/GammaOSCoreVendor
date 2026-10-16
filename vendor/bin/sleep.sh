#!/system/bin/sh
# GammaOS RP Duo Lite (SM6125) ultra low power sleep: forced suspend while the screen is off.
# init starts this from init.gammaos_power.rc (force_sleep, 5 s after screen off) when
# persist.gammaos.ultra_low_power_saving_mode=1, no USB data link and no charger
# (debug.tracing.plug_type=0) and boot completed. Screen on, USB or a charger stop it and
# run wake.sh; the script also reads the PMIC itself, so a plug is noticed even while the
# framework is still catching up after a wake.
#
# 1. Radios off. Connected Wi-Fi woke the SoC about once a second (WLAN copy-engine interrupt,
#    5177 wakeups in 109 minutes, awake half the time). Wi-Fi (if the user's wifi_on toggle is
#    on) and Bluetooth (only bluetooth_on=1; 2 means airplane mode already has it off) are
#    switched off here and back on by wake.sh. The restore flags are persistent so a reboot
#    mid-sleep still gets the radios back. Anything that turns Wi-Fi back on during the sleep
#    (nano's start-time auto-enable) is caught by the WLAN interrupts reappearing.
# 2. Wakeup sources trimmed to the power keys, the gpio keys, the lid hall sensor and the
#    charger plug-in (so a plug can wake the SoC and stop this script), re-checked every attempt.
# 3. Every attempt does the wakeup_count handshake, so a key press or a driver that is mid-
#    event still counts; a source that keeps refusing for HS_GRACE seconds is overridden with a
#    plain write to /sys/power/state, which also ignores framework wakelocks. Only two of nano's
#    kernel wakelocks are honoured: nano_ota (an update must not be frozen mid-write) and, for
#    up to 12 s, nano_wake (nano bringing the screen back). nano_music (screen-off playback)
#    is not: ultra low power sleep means the SoC sleeps even if music was playing.
# 4. Every attempt is checked against the kernel's suspend counter and logged with its length,
#    the SoC vmin time and the wake reason in /data/vendor/gammaos/sleep.log; aborts are retried
#    after 1 s and logged at the start of a streak and every 60th. vendor.gammaos.sleep.stats
#    has the running totals and wake.sh logs the session summary.
#
# The SoC offers only s2idle (/sys/power/mem_sleep); from it the RPM still collapses the apps
# subsystem and takes the SoC to vmin (XO off), which qcom_sleep_stats/vmin counts.
STATE=/sys/power/state
WCOUNT=/sys/power/wakeup_count
STATS=/sys/power/suspend_stats
REASON=/sys/kernel/wakeup_reasons/last_resume_reason
DBG=/sys/kernel/debug
VMIN=$DBG/qcom_sleep_stats/vmin
WS=$DBG/wakeup_sources
USB_PSY=/sys/class/power_supply/usb
LOGDIR=/data/vendor/gammaos
LOG=$LOGDIR/sleep.log
LOG_MAX=262144
WIFI_FLAG=persist.vendor.gammaos.sleep.wifi_restore
BT_FLAG=persist.vendor.gammaos.sleep.bt_restore
BT_APM=persist.vendor.gammaos.sleep.bt_apm
HS_GRACE=10          # s a refusing wakeup source may hold the sleep off before it is overridden
WAKE_HOLD_MAX=12     # 1 s polls nano_wake is honoured for
SOC=/sys/devices/platform/soc
SPMI=$SOC/1c40000.qcom,spmi/spmi-0
SMB5=$SPMI/0-02/1c40000.qcom,spmi:qcom,pmi632@2:qcom,qpnp-smb5

mkdir -p "$LOGDIR"
if [ "$(stat -c %s "$LOG" 2>/dev/null || echo 0)" -gt "$LOG_MAX" ]; then mv -f "$LOG" "$LOG.1"; fi
nlog=0
log() {
  nlog=$((nlog + 1))
  if [ $((nlog % 100)) -eq 0 ] && [ "$(stat -c %s "$LOG" 2>/dev/null || echo 0)" -gt "$LOG_MAX" ]; then
    mv -f "$LOG" "$LOG.1"
  fi
  echo "$(date '+%m-%d %H:%M:%S') sleep: $*" >> "$LOG"
}

# VBUS straight from the PMIC (USBIN present; online reads 0 on a PC port), so a cable or
# charger stops the sleep without waiting for the framework to publish it.
ext_power() {
  [ "$(cat $USB_PSY/present 2>/dev/null)" = 1 ] || [ "$(cat $USB_PSY/online 2>/dev/null)" = 1 ]
}
power_state() {
  echo "screen=$(getprop sys.screen.state) usb=$(getprop sys.gammaos.usb.connected) plug=$(getprop debug.tracing.plug_type) present=$(cat $USB_PSY/present 2>/dev/null) online=$(cat $USB_PSY/online 2>/dev/null)"
}
still_wanted() {
  [ "$(getprop sys.screen.state)" != "on" ] &&
  [ "$(getprop sys.gammaos.usb.connected)" != "1" ] &&
  case "$(getprop debug.tracing.plug_type)" in ""|0) true ;; *) false ;; esac &&
  ! ext_power &&
  [ "$(getprop persist.gammaos.ultra_low_power_saving_mode)" = "1" ]
}

boottime() { awk '{print $1}' /proc/uptime; }
up_s() { read -r u _ < /proc/uptime; echo "${u%.*}"; }
# vmin entry count and accumulated seconds (19.2 MHz ticks; 64-bit, so awk and not $(( )))
vmin_read() {
  [ -r "$VMIN" ] || { echo "0 0"; return; }
  awk '/^Count/{c=$3} /^Accumulated Duration/{d=$4} END{printf "%d %.3f\n", c, d/19200000}' "$VMIN"
}
# RPM master sleep stats: per subsystem "numshutdowns" (hex) and "xo_accumulated_duration"
# (hex, 19.2 MHz ticks). Printed as "APSS:n/s MPSS:n/s ADSP:n/s CDSP:n/s" where n is the
# shutdown count and s the XO-off seconds; the per-sleep delta names the master that stayed
# awake and kept the SoC out of vmin.
MSTATS=$DBG/rpm_master_stats
masters_read() {
  [ -r "$MSTATS" ] || { echo ""; return; }
  awk 'function hex(str,  i, c, v) { v = 0; str = tolower(substr(str, index(str, "0x") + 2));
         for (i = 1; i <= length(str); i++) { c = index("0123456789abcdef", substr(str, i, 1)); if (c == 0) break; v = v * 16 + c - 1 }
         return v }
       /^[A-Z]+[ \t]*$/ && !seen[$1]++ {m=$1} /numshutdowns/ {n[m]=hex($0)} /xo_accumulated_duration/ {x[m]=hex($0)}
       END {for (k in n) printf "%s:%d/%.1f ", k, n[k], x[k]/19200000}' "$MSTATS"
}
masters_delta() {   # $1 before, $2 after -> "APSS:+1/+39.8s ..."
  echo "$1" | tr " " "\n" | awk -v after="$2" -F'[:/]' 'NF==3 {b_n[$1]=$2; b_x[$1]=$3} END {
    n=split(after, a, " "); for (i=1;i<=n;i++) { split(a[i], f, "[:/]"); if (f[1]=="") continue;
      printf "%s:+%d/+%.1fs ", f[1], f[2]-b_n[f[1]], f[3]-b_x[f[1]] } }'
}

# debugfs wakeup_sources: fields split by runs of tabs, the name padded (and blank for some)
active_ws() {
  awk -F '\t+' 'NR > 1 && $6 + 0 > 0 { n = $1; gsub(/ +$/, "", n); printf "%s ", (n == "" ? "(unnamed)" : n) }' "$WS" 2>/dev/null
}

wake_polls=0
nano_hold() {
  case " $(cat /sys/power/wake_lock 2>/dev/null) " in
    *" nano_ota "*) return 0 ;;
    *" nano_wake "*)
      wake_polls=$((wake_polls + 1))
      [ $wake_polls -le $WAKE_HOLD_MAX ] && return 0
      return 1 ;;
  esac
  wake_polls=0
  return 1
}

wifi_wanted() {
  case "$(timeout 5 settings get global wifi_on 2>/dev/null)" in 1|2) return 0 ;; esac
  return 1
}

radios_off() {
  # wifi_on is the user's persisted toggle (1 on, 2 on in airplane mode); unlike the live status
  # it also reads on while Wi-Fi is still ENABLING.
  if wifi_wanted; then
    setprop "$WIFI_FLAG" 1             # before the switch, so a kill midway still restores
    timeout 10 cmd wifi set-wifi-enabled disabled >/dev/null 2>&1
    # the driver frees its copy-engine interrupts once it is really down
    i=0
    while [ $i -lt 40 ] && grep -q WLAN_CE /proc/interrupts; do sleep 0.25; i=$((i + 1)); done
    log "wifi off (WLAN_CE irqs left: $(grep -c WLAN_CE /proc/interrupts))"
  fi
  if [ "$(timeout 5 settings get global bluetooth_on 2>/dev/null)" = "1" ]; then
    # Inside an airplane-mode session the shell toggle is recorded as a user choice; keep the
    # two airplane preferences so wake.sh can put them back.
    if [ "$(timeout 5 settings get global airplane_mode_on 2>/dev/null)" = "1" ]; then
      setprop "$BT_APM" "$(timeout 5 settings get secure bluetooth_apm_state 2>/dev/null) $(timeout 5 settings get secure apm_user_toggled_bluetooth 2>/dev/null)"
    fi
    setprop "$BT_FLAG" 1
    timeout 10 cmd bluetooth_manager disable >/dev/null 2>&1
    timeout 5 cmd bluetooth_manager wait-for-state:STATE_OFF >/dev/null 2>&1
    log "bluetooth off (bluetooth_on=$(timeout 5 settings get global bluetooth_on 2>/dev/null))"
  fi
}

set_wakeup() {   # $1 = enabled|disabled, then paths; writes only on a change
  v=$1; shift
  for f in "$@"; do
    [ -e "$f" ] || continue
    [ "$(cat "$f" 2>/dev/null)" = "$v" ] || echo "$v" > "$f"
  done
}
trim_wakeups() {
  set_wakeup disabled \
    $SOC/c800000.qcom,icnss/power/wakeup \
    $SOC/6080000.remoteproc-mss/power/wakeup \
    $SOC/ab00000.remoteproc-adsp/power/wakeup \
    $SOC/b300000.remoteproc-cdsp/power/wakeup \
    $SOC/1610000.qcom,msm-eud/power/wakeup \
    $SOC/4e00000.ssusb/power/wakeup \
    $SMB5/power_supply/battery/power/wakeup \
    $SMB5/power_supply/pc_port/power/wakeup \
    $SPMI/0-02/1c40000.qcom,spmi:qcom,pmi632@2:qpnp,qg/power_supply/bms/power/wakeup \
    $SPMI/0-00/1c40000.qcom,spmi:qcom,pm6125@0:qcom,pm6125_rtc/power/wakeup \
    $SPMI/0-00/1c40000.qcom,spmi:qcom,pm6125@0:qcom,pm6125_rtc/rtc/rtc0/alarmtimer.0.auto/power/wakeup \
    $SOC/soc:qcom,msm-audio-apr/soc:qcom,msm-audio-apr:qcom,q6core-audio/soc:qcom,msm-audio-apr:qcom,q6core-audio:bolero-cdc/tx-macro/tx_swr_ctrl/power/wakeup \
    $SOC/4ac0000.qcom,qupv3_0_geni_se/*/i2c-*/*/*smb1355*/power_supply/parallel/power/wakeup \
    /sys/devices/virtual/misc/msm_*/power/wakeup
  # power keys, volume (gpio keys), the lid, and the charger plug-in
  set_wakeup enabled \
    $SPMI/0-00/1c40000.qcom,spmi:qcom,pm6125@0:qcom,power-on@800/power/wakeup \
    $SPMI/0-02/1c40000.qcom,spmi:qcom,pmi632@2:qcom,power-on@800/power/wakeup \
    $SOC/soc:gpio_keys/power/wakeup \
    $SOC/soc:hall@0/power/wakeup \
    $SMB5/power/wakeup \
    $SMB5/power_supply/usb/power/wakeup
}

# A wake by the power key, a gpio key or the lid is the user: give the framework time to turn
# the screen on (init then stops this script) instead of suspending again underneath it.
user_wake() {
  case "$1" in
    *kpdpwr*|*pon_resin*|*volume*|*hall*|*gpio*key*) return 0 ;;
  esac
  return 1
}

# The wakeup_count handshake makes kernel wakeup sources (a key event still queued, a driver
# mid-event) abort the attempt; a source still refusing after HS_GRACE seconds is overridden.
hs_since=
suspend_now() {
  if [ -z "$hs_since" ] || [ $(( $(up_s) - hs_since )) -lt $HS_GRACE ]; then
    c=$(timeout 2 cat "$WCOUNT" 2>/dev/null)
    if [ -z "$c" ] || ! echo "$c" > "$WCOUNT" 2>/dev/null; then
      [ -n "$hs_since" ] || hs_since=$(up_s)
      return 1
    fi
  fi
  echo mem > "$STATE" 2>/dev/null
  return 0
}

[ -d "$DBG/qcom_sleep_stats" ] || mount -t debugfs debugfs "$DBG" 2>/dev/null
still_wanted || { log "not started ($(power_state))"; exit 0; }
if nano_hold; then
  log "waiting: nano holds $(cat /sys/power/wake_lock 2>/dev/null)"
  while still_wanted && nano_hold; do sleep 1; done
  still_wanted || { log "not started after the nano hold ($(power_state))"; exit 0; }
fi
log "start ($(power_state))"
setprop vendor.gammaos.sleep.session "1 $(cat $STATS/success) $(cat $STATS/fail)"
setprop vendor.gammaos.sleep.stats "sleeps=0 aborts=0 streak=0 slept=0s vmin=0s"
radios_off
if [ -w /sys/power/mem_sleep ] && grep -q deep /sys/power/mem_sleep 2>/dev/null; then
  echo deep > /sys/power/mem_sleep 2>/dev/null
fi

ok=0; fail=0; aborts=0; slept_total=0; vmin_total=0; reason=""
while still_wanted; do
  if nano_hold; then sleep 1; continue; fi
  if grep -q WLAN_CE /proc/interrupts && wifi_wanted; then
    log "wifi back on during the sleep (last wake: $reason), switching it off again"
    radios_off
  fi
  trim_wakeups
  s0=$(cat $STATS/success); t0=$(boottime); set -- $(vmin_read); vc0=$1; vs0=$2; m0="$(masters_read)"
  refused=0; suspend_now || refused=1
  s1=$(cat $STATS/success); t1=$(boottime); set -- $(vmin_read); vc1=$1; vs1=$2; m1="$(masters_read)"
  reason="$(cat $REASON 2>/dev/null)"
  [ $refused -eq 1 ] && reason="refused, wakeup source active: $(active_ws)"
  if [ "$s1" -gt "$s0" ]; then
    ok=$((ok + 1)); hs_since=
    set -- $(awk -v a="$t0" -v b="$t1" -v c="$vs0" -v d="$vs1" -v s="$slept_total" -v v="$vmin_total" \
      'BEGIN{printf "%.1f %.1f %.1f %.1f\n", b-a, d-c, s+(b-a), v+(d-c)}')
    slept_total=$3; vmin_total=$4
    log "slept ${1}s, vmin ${2}s in $((vc1 - vc0)) entries, masters $(masters_delta "$m0" "$m1")$([ $aborts -gt 0 ] && echo ", after $aborts aborts"), woke: $reason"
    aborts=0
  else
    fail=$((fail + 1)); aborts=$((aborts + 1))
    if [ $aborts -eq 1 ] || [ $((aborts % 60)) -eq 0 ]; then
      log "aborted ($aborts in a row): $reason (dev $(cat $STATS/last_failed_dev 2>/dev/null | head -n 1))"
    fi
  fi
  setprop vendor.gammaos.sleep.stats "sleeps=$ok aborts=$fail streak=$aborts slept=${slept_total}s vmin=${vmin_total}s"
  ext_power && break                 # a plug woke us: stop now, not after the next suspend
  # A user key or the lid (as the wake reason, or as the wakeup source that aborted the attempt)
  # gets up to 6 s for the screen to come on; anything else is retried after 1 s.
  if user_wake "$reason"; then
    i=0
    while [ $i -lt 12 ] && still_wanted; do sleep 0.5; i=$((i + 1)); done
  else
    sleep 1
  fi
done
setprop vendor.gammaos.sleep.session 0
log "stop ($(power_state)) sleeps=$ok aborts=$fail streak=$aborts slept=${slept_total}s vmin=${vmin_total}s"
# A charger or cable ended the sleep with the screen still off: put the radios and the stock
# wakeup sources back here (synchronously: init kills this oneshot's process group on exit).
if ext_power && [ "$(getprop sys.screen.state)" != "on" ]; then
  log "external power, undoing the forced sleep"
  /vendor/bin/wake.sh
fi

#!/system/bin/sh
# GammaOS RP Duo Lite: undo sleep.sh. init runs this (force_wake) on screen on, on a USB data
# connection and on a charger (debug.tracing.plug_type), and sleep.sh runs it itself when it
# sees VBUS with the screen still off. Re-enables every wakeup source the forced sleep
# disabled, so the framework's normal suspend keeps the stock wake behaviour (charger, USB,
# Wi-Fi, alarms), and switches Wi-Fi and Bluetooth back on if sleep.sh turned them off. The
# restore flags are persistent, and the radio services may not be up yet when this runs at
# boot, so it waits for them (up to 30 s). A flag is cleared once the framework accepted the
# switch-on request (which persists wifi_on / bluetooth_on = 1); bringing the radio up is the
# framework's job from there.
SOC=/sys/devices/platform/soc
SPMI=$SOC/1c40000.qcom,spmi/spmi-0
LOG=/data/vendor/gammaos/sleep.log
WIFI_FLAG=persist.vendor.gammaos.sleep.wifi_restore
BT_FLAG=persist.vendor.gammaos.sleep.bt_restore
BT_APM=persist.vendor.gammaos.sleep.bt_apm
log() { [ -d "${LOG%/*}" ] && echo "$(date '+%m-%d %H:%M:%S') wake: $*" >> "$LOG"; }

# Session summary: init SIGKILLs sleep.sh on screen on, so it cannot write its own.
sess="$(getprop vendor.gammaos.sleep.session)"
case "$sess" in
  1\ *)
    setprop vendor.gammaos.sleep.session 0
    set -- $sess
    log "session end: $(getprop vendor.gammaos.sleep.stats), kernel suspends +$(( $(cat /sys/power/suspend_stats/success) - $2 )) fails +$(( $(cat /sys/power/suspend_stats/fail) - $3 )), screen=$(getprop sys.screen.state) plug=$(getprop debug.tracing.plug_type)"
    ;;
esac

for f in \
  $SOC/c800000.qcom,icnss/power/wakeup \
  $SOC/6080000.remoteproc-mss/power/wakeup \
  $SOC/ab00000.remoteproc-adsp/power/wakeup \
  $SOC/b300000.remoteproc-cdsp/power/wakeup \
  $SOC/1610000.qcom,msm-eud/power/wakeup \
  $SOC/4e00000.ssusb/power/wakeup \
  $SPMI/0-02/1c40000.qcom,spmi:qcom,pmi632@2:qcom,qpnp-smb5/power/wakeup \
  $SPMI/0-02/1c40000.qcom,spmi:qcom,pmi632@2:qcom,qpnp-smb5/power_supply/battery/power/wakeup \
  $SPMI/0-02/1c40000.qcom,spmi:qcom,pmi632@2:qcom,qpnp-smb5/power_supply/pc_port/power/wakeup \
  $SPMI/0-02/1c40000.qcom,spmi:qcom,pmi632@2:qcom,qpnp-smb5/power_supply/usb/power/wakeup \
  $SPMI/0-02/1c40000.qcom,spmi:qcom,pmi632@2:qpnp,qg/power_supply/bms/power/wakeup \
  $SPMI/0-00/1c40000.qcom,spmi:qcom,pm6125@0:qcom,pm6125_rtc/power/wakeup \
  $SPMI/0-00/1c40000.qcom,spmi:qcom,pm6125@0:qcom,pm6125_rtc/rtc/rtc0/alarmtimer.0.auto/power/wakeup \
  $SOC/soc:qcom,msm-audio-apr/soc:qcom,msm-audio-apr:qcom,q6core-audio/soc:qcom,msm-audio-apr:qcom,q6core-audio:bolero-cdc/tx-macro/tx_swr_ctrl/power/wakeup \
  $SOC/4ac0000.qcom,qupv3_0_geni_se/*/i2c-*/*/*smb1355*/power_supply/parallel/power/wakeup \
  /sys/devices/virtual/misc/msm_*/power/wakeup
do
  [ -e "$f" ] || continue
  [ "$(cat "$f" 2>/dev/null)" = enabled ] || echo enabled > "$f"
done

i=0
while [ $i -lt 60 ]; do
  w="$(getprop $WIFI_FLAG)"; b="$(getprop $BT_FLAG)"
  [ "$w" != "1" ] && [ "$b" != "1" ] && break
  if [ "$w" = "1" ] && timeout 5 cmd wifi status >/dev/null 2>&1; then
    if timeout 10 cmd wifi set-wifi-enabled enabled >/dev/null 2>&1; then
      setprop $WIFI_FLAG 0
      log "wifi on"
    fi
  fi
  if [ "$b" = "1" ] && timeout 10 cmd bluetooth_manager enable >/dev/null 2>&1; then
    # put back the airplane-mode Bluetooth preferences the shell toggles rewrote
    apm="$(getprop $BT_APM)"
    if [ -n "$apm" ]; then
      set -- $apm
      for kv in "bluetooth_apm_state $1" "apm_user_toggled_bluetooth $2"; do
        set -- $kv
        if [ "$2" = "null" ] || [ -z "$2" ]; then settings delete secure "$1" >/dev/null 2>&1
        else settings put secure "$1" "$2" >/dev/null 2>&1; fi
      done
      setprop $BT_APM ""
    fi
    setprop $BT_FLAG 0
    log "bluetooth on"
  fi
  sleep 0.5
  i=$((i + 1))
done

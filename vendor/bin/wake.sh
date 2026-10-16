#!/system/bin/sh
# GammaOS RP Duo Lite: undo sleep.sh on screen on. Re-enable every wakeup source the forced
# sleep disabled so the framework's own suspend (screen off without ultra low power mode)
# keeps the stock wake behaviour (charger, USB, Wi-Fi, alarms).
SOC=/sys/devices/platform/soc
SPMI=$SOC/1c40000.qcom,spmi/spmi-0
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
  [ -e "$f" ] && echo enabled > "$f"
done

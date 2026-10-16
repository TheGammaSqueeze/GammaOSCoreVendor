#!/system/bin/sh
# GammaOS RP Duo Lite (SM6125) ultra low power sleep: forced suspend while the screen is
# off (init starts this from init.gammaos_power.rc when persist.gammaos.ultra_low_power_saving_mode
# is on, the screen is off and no USB is connected; stopped on screen on). The SoC only offers
# s2idle (/sys/power/mem_sleep), which is what "mem" selects here.
#
# Wakeup sources are trimmed first so the sleep is not cut short by charger, battery gauge,
# Wi-Fi, audio or DSP wakeups: only the PMIC power key, the gpio keys and the lid hall sensor may
# wake the device. wake.sh re-enables everything on screen on so the framework's normal suspend
# keeps the stock wake behaviour.
STATE="/sys/power/state"
MEM_SLEEP="/sys/power/mem_sleep"
INTERVAL_SEC=10
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
  $SOC/soc:qcom,msm-audio-apr/soc:qcom,msm-audio-apr:qcom,q6core-audio/soc:qcom,msm-audio-apr:qcom,q6core-audio:bolero-cdc/tx-macro/tx_swr_ctrl/power/wakeup
do
  [ -e "$f" ] && echo disabled > "$f"
done
for f in $SOC/4ac0000.qcom,qupv3_0_geni_se/*/i2c-*/*/*smb1355*/power_supply/parallel/power/wakeup \
         /sys/devices/virtual/misc/msm_*/power/wakeup; do
  [ -e "$f" ] && echo disabled > "$f"
done

# Keep only what should wake the device
for f in \
  $SPMI/0-00/1c40000.qcom,spmi:qcom,pm6125@0:qcom,power-on@800/power/wakeup \
  $SPMI/0-02/1c40000.qcom,spmi:qcom,pmi632@2:qcom,power-on@800/power/wakeup \
  $SOC/soc:gpio_keys/power/wakeup \
  $SOC/soc:hall@0/power/wakeup
do
  [ -e "$f" ] && echo enabled > "$f"
done

if [ -w "$MEM_SLEEP" ] && grep -q "deep" "$MEM_SLEEP" 2>/dev/null; then
  echo deep > "$MEM_SLEEP" 2>/dev/null
fi

# Request suspend; a wakeup source still active aborts the attempt and the loop retries.
while :; do
  echo mem > "$STATE" 2>/dev/null
  sleep "$INTERVAL_SEC"
done

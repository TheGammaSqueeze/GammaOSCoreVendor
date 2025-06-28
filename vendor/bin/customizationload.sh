# only run once per install
if [ ! -e /data/isGammaNewInstall ]; then

  echo "This is an upgrade"
  settings put --lineage system key_back_long_press_action 11

  settings put secure sysui_qs_tiles \
    internet,bt,performance,abxy,mappingeditor,deepsleepmode,rotation, \
    dpadAnalogToggle,analogsensitivity,analogdeadzone,analogcalibration, \
    analogaxis,rightanalogaxis,dcdimmingemulation,retroarchmenubuttonoverride

  pm uninstall com.ktpocket.launcher

  setprop ctl.stop gammapad
  setprop ctl.stop remove_mtk_pmic_keys

  for i in 1 2 3; do
    echo soc:odm:kte-joystick > /sys/bus/platform/drivers/kte-gpio-keys/unbind
  done
  for i in 1 2 3; do
    echo soc:odm:kte-joystick > /sys/bus/platform/drivers/kte-gpio-keys/bind
  done

  echo mtk-pmic-keys > /sys/bus/platform/drivers/mtk-pmic-keys/unbind
  sleep 0.5
  echo mtk-pmic-keys > /sys/bus/platform/drivers/mtk-pmic-keys/bind

  setprop ctl.start gammapad
  sleep 1
  setprop ctl.start remove_mtk_pmic_keys

  am start --user current -n com.gamma.analogcalibrator/.MainActivity

  # mark as done
  touch /data/isGammaNewInstall

fi

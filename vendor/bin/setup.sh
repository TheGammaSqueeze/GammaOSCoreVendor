settings put secure sysui_qs_tiles internet,bt,performance,usbcontrollerswitch,abxy,mappingeditor,fan,deepsleepmode,rotation,dpadAnalogToggle,analogsensitivity,analogdeadzone,analogcalibration,analogaxis,rightanalogaxis,dcdimmingemulation,retroarchmenubuttonoverride

mkdir -p /data/GammaPad

printf '%s\n' \
  "BTN_GAMEPAD BTN_GAMEPAD" \
  "BTN_EAST BTN_EAST" \
  "BTN_NORTH BTN_NORTH" \
  "BTN_WEST BTN_WEST" \
  "BTN_TL BTN_TL" \
  "BTN_TR BTN_TR" \
  "BTN_SELECT BTN_SELECT" \
  "BTN_START BTN_START" \
  "BTN_MODE BTN_MODE" \
  "BTN_THUMBL BTN_THUMBL" \
  "BTN_THUMBR BTN_THUMBR" \
  "754 KEY_BACK" \
  "753 KEY_ALL_APPLICATIONS" \
  "760 KEY_MENU" \
> /data/GammaPad/MAPPINGS

stop gammapad
start gammapad

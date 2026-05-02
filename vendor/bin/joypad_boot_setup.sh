#!/system/bin/sh
set -eu

CAL="/sys/devices/platform/11005000.i2c6/i2c-6/6-0048/calibration"
SW="/sys/devices/platform/gpio-keys/keyswitch"
INI="/mnt/vendor/protect_f/calibration.ini"

log() { echo "[joypad_boot] $*" > /dev/kmsg; }

wcal() {
  cmd="$1"
  log "WRITE: $cmd"
  printf '%s\n' "$cmd" > "$CAL"
}

getp() {
  key="$1"
  awk -F= -v k="$key" '($1==k){gsub(/\r/,"",$2); print $2; exit}' "$INI"
}

is_int() {
  case "${1:-}" in
    ''|*[!0-9-]*) return 1 ;;
    *) return 0 ;;
  esac
}

# Validate joystick tuple: min < max, span >= 500, center in [min,max]
valid_joy() {
  mn="$1"; mx="$2"; ct="$3"
  is_int "$mn" && is_int "$mx" && is_int "$ct" || return 1
  [ "$mn" -lt "$mx" ] || return 1
  [ $((mx - mn)) -ge 500 ] || return 1
  [ "$ct" -ge "$mn" ] && [ "$ct" -le "$mx" ] || return 1
  return 0
}

# Validate trigger tuple: min < max, span >= 500
valid_tri() {
  mn="$1"; mx="$2"
  is_int "$mn" && is_int "$mx" || return 1
  [ "$mn" -lt "$mx" ] || return 1
  [ $((mx - mn)) -ge 500 ] || return 1
  return 0
}

# --- AYANEO mode ---
log "Setting AYANEO joystick mode"
wcal "set-joy-MD,1,0,0,0,0,0"

# --- Japan-swapped layout ---
log "Setting Japan-swapped button layout"
echo 1 > "$SW"

# --- Calibration restore ---
if [ ! -f "$INI" ]; then
  log "No $INI found. Falling back to safe defaults."
  wcal "set-cal-S,0,0,0,0,0,0"
  wcal "cal-joy-L,1000,4500,2500,1000,4500,2500"
  wcal "cal-joy-R,1000,4500,2500,1000,4500,2500"
  wcal "set-joy-LD,0,0,0,0,0,0"
  wcal "set-joy-RD,0,0,0,0,0,0"
  wcal "set-tri-LD,25,25,0,0,0,0"
  wcal "set-tri-RD,25,25,0,0,0,0"
  wcal "set-cal-E,0,0,0,0,0,0"
  exit 0
fi

# Read values
LXM="$(getp joy_left_x_min)";  LXX="$(getp joy_left_x_max)";  LXC="$(getp joy_left_x_center)"
LYM="$(getp joy_left_y_min)";  LYX="$(getp joy_left_y_max)";  LYC="$(getp joy_left_y_center)"
RXM="$(getp joy_right_x_min)"; RXX="$(getp joy_right_x_max)"; RXC="$(getp joy_right_x_center)"
RYM="$(getp joy_right_y_min)"; RYX="$(getp joy_right_y_max)"; RYC="$(getp joy_right_y_center)"

# Sanity check. If any invalid, use safe defaults for that axis.
if ! valid_joy "$LXM" "$LXX" "$LXC"; then LXM=1000; LXX=4500; LXC=2500; fi
if ! valid_joy "$LYM" "$LYX" "$LYC"; then LYM=1000; LYX=4500; LYC=2500; fi
if ! valid_joy "$RXM" "$RXX" "$RXC"; then RXM=1000; RXX=4500; RXC=2500; fi
if ! valid_joy "$RYM" "$RYX" "$RYC"; then RYM=1000; RYX=4500; RYC=2500; fi

log "Applying joystick calibration:"
log "  L: X $LXM,$LXX,$LXC | Y $LYM,$LYX,$LYC"
log "  R: X $RXM,$RXX,$RXC | Y $RYM,$RYX,$RYC"

wcal "set-cal-S,0,0,0,0,0,0"
wcal "cal-joy-L,$LXM,$LXX,$LXC,$LYM,$LYX,$LYC"
wcal "cal-joy-R,$RXM,$RXX,$RXC,$RYM,$RYX,$RYC"
wcal "set-joy-LD,0,0,0,0,0,0"
wcal "set-joy-RD,0,0,0,0,0,0"

# --- Trigger calibration ---
TLM="$(getp tri_left_min)";  TLX="$(getp tri_left_max)"
TRM="$(getp tri_right_min)"; TRX="$(getp tri_right_max)"

if valid_tri "$TLM" "$TLX"; then
  log "Applying left trigger calibration: min=$TLM max=$TLX"
  wcal "cal-tri-L,$TLX,$TLM,0,0,0,0"
else
  log "Left trigger calibration invalid or missing, skipping"
fi

if valid_tri "$TRM" "$TRX"; then
  log "Applying right trigger calibration: min=$TRM max=$TRX"
  wcal "cal-tri-R,$TRX,$TRM,0,0,0,0"
else
  log "Right trigger calibration invalid or missing, skipping"
fi

# --- Trigger deadzones (25% bottom, 25% top) ---
wcal "set-tri-LD,25,25,0,0,0,0"
wcal "set-tri-RD,25,25,0,0,0,0"

wcal "set-cal-E,0,0,0,0,0,0"

log "Done."

#!/system/bin/sh

sleep 10
swapoff /dev/block/zram0 2>/dev/null

CPU_THRESHOLD=102
CPU_CRITICAL=103
CPU_EMERGENCY=104
CPU_SHUTDOWN=117

GPU_THRESHOLD=102
GPU_CRITICAL=103
GPU_EMERGENCY=104
GPU_SHUTDOWN=117

SKIN_THRESHOLD=50
SKIN_CRITICAL=60
SKIN_EMERGENCY=70
SKIN_SHUTDOWN=80

TARGET_C="${TARGET_C:-110}"

# Safety knobs
SAFETY_MARGIN_C="${SAFETY_MARGIN_C:-5}"
SAFE_MAX_C="117"  # if empty, auto-detect from kernel trips

STOP_THERMAL_CORE="0"         # default 0 to keep vendor throttling alive
RESTART_THERMAL_CORE="1"   # rarely needed

SOCK="/dev/socket/thermal_hal_socket"

die() { echo "ERROR: $*" >&2; exit 1; }

nc_send() {
  # $1 = line to send
  printf '%s\n' "$1" | nc -U "$SOCK" >/dev/null 2>&1
}

dump_line() {
  # $1 = CPU/GPU/SKIN
  dumpsys thermalservice 2>/dev/null | grep -m 1 "TemperatureThreshold{.*mName=$1,"
}

print_block() {
  echo "== $1:"
  dump_line CPU
  dump_line GPU
  dump_line SKIN
  echo
}

last4_from_line() {
  # stdin: one TemperatureThreshold line
  # output: "severe critical emergency shutdown" (strings, like 110.0)
  sed -n 's/.*mHotThrottlingThresholds=\[\([^]]*\)\].*/\1/p' \
    | tr -d ' ' \
    | awk -F',' '{print $(NF-3) " " $(NF-2) " " $(NF-1) " " $NF}'
}

norm() {
  # normalize "110.0" -> "110"
  echo "$1" | sed 's/\.0*$//'
}

clamp_int() {
  # $1=value $2=min $3=max
  v="$1"; lo="$2"; hi="$3"
  [ -z "$v" ] && v="$lo"
  [ "$v" -lt "$lo" ] && v="$lo"
  [ "$v" -gt "$hi" ] && v="$hi"
  echo "$v"
}

min_int() {
  a="$1"; b="$2"
  [ "$a" -le "$b" ] && echo "$a" || echo "$b"
}

# Read a thermal zone trip (millidegree C) and print integer C (floor)
read_zone_trip_c() {
  # $1=zone path, $2=trip index
  z="$1"
  i="$2"
  tp="$z/trip_point_${i}_temp"
  [ -f "$tp" ] || return 1
  v="$(cat "$tp" 2>/dev/null)" || return 1
  case "$v" in
    ''|*[!0-9]*) return 1 ;;
  esac
  echo $((v / 1000))
}

read_zone_temp_c() {
  # $1=zone path
  z="$1"
  v="$(cat "$z/temp" 2>/dev/null)" || return 1
  case "$v" in
    ''|*[!0-9-]*) return 1 ;;
  esac
  echo $((v / 1000))
}

# Pick a conservative cap from kernel trips:
# - gpu2 (often 105C trip)
# - soc_max (often 119C critical)
detect_safe_max_c() {
  # Allow user forced SAFE_MAX_C
  if [ -n "$SAFE_MAX_C" ]; then
    echo "$SAFE_MAX_C"
    return 0
  fi

  best=""

  # Helper: update best=min(best, (trip - margin))
  upd_best_from_trip() {
    tripc="$1"
    [ -z "$tripc" ] && return 0
    cap=$((tripc - SAFETY_MARGIN_C))
    [ "$cap" -lt 0 ] && cap=0
    if [ -z "$best" ] || [ "$cap" -lt "$best" ]; then
      best="$cap"
    fi
  }

  # Locate zones by type for portability
  socz=""
  gpuz=""

  for z in /sys/class/thermal/thermal_zone*; do
    t="$(cat "$z/type" 2>/dev/null)" || continue
    [ "$t" = "soc_max" ] && socz="$z"
    [ "$t" = "gpu2" ] && gpuz="$z"
  done

  # Use trip0 temps if present
  if [ -n "$gpuz" ]; then
    tp="$(read_zone_trip_c "$gpuz" 0 2>/dev/null)"
    upd_best_from_trip "$tp"
  fi
  if [ -n "$socz" ]; then
    tp="$(read_zone_trip_c "$socz" 0 2>/dev/null)"
    upd_best_from_trip "$tp"
  fi

  # Fallback if nothing detected
  if [ -z "$best" ]; then
    best=100
  fi

  echo "$best"
}

get_cfg() {
  # $1 = NAME (CPU/GPU/SKIN)
  # $2 = KEY  (THRESHOLD/CRITICAL/EMERGENCY/SHUTDOWN)
  eval v="\${${1}_${2}:-}"
  if [ -n "$v" ]; then
    echo "$v"
  else
    echo "$TARGET_C"
  fi
}

set_one() {
  # $1 = NAME, $2 = KEY, $3 = VALUE
  nc_send "TYPE=thermal_hal_update NAME=$1 $2=$3"
}

apply_name() {
  # $1 = NAME
  n="$1"

  th="$(get_cfg "$n" THRESHOLD)"
  cr="$(get_cfg "$n" CRITICAL)"
  em="$(get_cfg "$n" EMERGENCY)"
  shd="$(get_cfg "$n" SHUTDOWN)"

  # Clamp everything to SAFE_MAX and keep monotonic: th <= cr <= em <= shd
  th="$(clamp_int "$th" 0 "$SAFE_CAP_C")"
  cr="$(clamp_int "$cr" "$th" "$SAFE_CAP_C")"
  em="$(clamp_int "$em" "$cr" "$SAFE_CAP_C")"
  shd="$(clamp_int "$shd" "$em" "$SAFE_CAP_C")"

  echo "== $n requested: th=$th cr=$cr em=$em shd=$shd (cap=$SAFE_CAP_C)"

  set_one "$n" THRESHOLD "$th" || return 1
  set_one "$n" CRITICAL  "$cr" || return 1
  set_one "$n" EMERGENCY "$em" || return 1
  set_one "$n" SHUTDOWN  "$shd" || return 1
  return 0
}

verify_one() {
  # $1 = NAME
  n="$1"
  line="$(dump_line "$n")"
  [ -n "$line" ] || { echo "  $n: missing threshold line"; return 1; }

  set -- $(echo "$line" | last4_from_line)
  got_sev="$(norm "$1")"
  got_cri="$(norm "$2")"
  got_eme="$(norm "$3")"
  got_shd="$(norm "$4")"

  # We verify against the clamped monotonic values we computed again
  th="$(clamp_int "$(get_cfg "$n" THRESHOLD)" 0 "$SAFE_CAP_C")"
  cr="$(clamp_int "$(get_cfg "$n" CRITICAL)" "$th" "$SAFE_CAP_C")"
  em="$(clamp_int "$(get_cfg "$n" EMERGENCY)" "$cr" "$SAFE_CAP_C")"
  shd="$(clamp_int "$(get_cfg "$n" SHUTDOWN)" "$em" "$SAFE_CAP_C")"

  exp_sev="$(norm "$th")"
  exp_cri="$(norm "$cr")"
  exp_eme="$(norm "$em")"
  exp_shd="$(norm "$shd")"

  echo "  $n parsed: severe=$got_sev critical=$got_cri emergency=$got_eme shutdown=$got_shd"
  echo "  $n expect: severe=$exp_sev critical=$exp_cri emergency=$exp_eme shutdown=$exp_shd"

  [ "$got_sev" = "$exp_sev" ] && \
  [ "$got_cri" = "$exp_cri" ] && \
  [ "$got_eme" = "$exp_eme" ] && \
  [ "$got_shd" = "$exp_shd" ]
}

# --- main ---
[ -S "$SOCK" ] || die "Socket missing: $SOCK (is vendor.thermal-mediatek running?)"

SAFE_CAP_C="$(detect_safe_max_c)"
echo "== Safety cap: SAFE_CAP_C=$SAFE_CAP_C (margin=${SAFETY_MARGIN_C}C)"
echo "   Note: this clamps CPU/GPU/SKIN thresholds below kernel trip points to avoid LVTS stage-3 HW reboot."

# If someone tries to stop thermal_core, refuse by default because it removes vendor-side throttling
if [ "$STOP_THERMAL_CORE" = "1" ] && [ "${FORCE_UNSAFE_STOP:-0}" != "1" ]; then
  echo "WARNING: STOP_THERMAL_CORE=1 increases risk of hitting HW thermal reboot."
  echo "         For safety, forcing STOP_THERMAL_CORE=0. Set FORCE_UNSAFE_STOP=1 to override."
  STOP_THERMAL_CORE=0
fi

print_block "Before"

if [ "$STOP_THERMAL_CORE" = "1" ]; then
  stop thermal_core >/dev/null 2>&1 || true
  sleep 1
fi

apply_name CPU  || die "Failed to update CPU via $SOCK"
apply_name GPU  || die "Failed to update GPU via $SOCK"
apply_name SKIN || die "Failed to update SKIN via $SOCK"

sleep 1

print_block "After"

echo "== Verify:"
ok=1
verify_one CPU  || ok=0
verify_one GPU  || ok=0
verify_one SKIN || ok=0

# Quick reality check: show key zone temps and trips if available
echo "== Quick check: key zone temps/trips =="
for z in /sys/class/thermal/thermal_zone*; do
  t="$(cat "$z/type" 2>/dev/null)" || continue
  case "$t" in
    soc_max|gpu2|gpu1|ap_ntc)
      temp="$(cat "$z/temp" 2>/dev/null)"
      tp0="$(cat "$z/trip_point_0_temp" 2>/dev/null)"
      tp0t="$(cat "$z/trip_point_0_type" 2>/dev/null)"
      echo "  $t temp=$temp trip0=${tp0t:-?}:${tp0:-?}  ($z)"
      ;;
  esac
done

if [ "$RESTART_THERMAL_CORE" = "1" ]; then
  start thermal_core >/dev/null 2>&1 || true
fi

if [ "$ok" -eq 1 ]; then
  echo "OK: thresholds match desired values (after safety clamping)."
  exit 0
fi

echo "NOT OK: thresholds did not match desired values (something is overwriting them)."
exit 2
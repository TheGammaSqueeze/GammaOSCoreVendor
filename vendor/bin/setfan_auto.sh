#!/system/bin/sh
# Auto-discover thermal zones (CPU & GPU) and set persist.gammaos.fan_mode_auto
# Works across Qualcomm/MediaTek/Exynos/etc.

PROP_VALUE_SCREEN="$(getprop sys.screen.state)"
PROP_VALUE_BRIGHTNESS="$(getprop debug.tracing.screen_brightness)"

# Turn fan off in a loop, then exit the script
fan_off_and_exit() {
    i=0
    while [ $i -lt 10 ]; do
        /vendor/bin/setfan_off.sh
        sleep 2
        i=$((i + 1))
    done
    exit 0
}

# If screen is off OR brightness is 0.0, turn fan off and stop here
if [ "$PROP_VALUE_SCREEN" = "off" ] || [ "$PROP_VALUE_BRIGHTNESS" = "0.0" ]; then
    fan_off_and_exit
fi

PROP_NAME="${PROP_NAME:-persist.gammaos.fan_mode_auto}"
SCAN_ROOT="/sys/class/thermal"
INTERVAL="${INTERVAL:-5}"   # seconds
last_mode=""

# --- helpers ---------------------------------------------------------------

# Read temperature and normalize to °C (integer). Returns "" on failure.
read_temp_c() {
  local node="$1" v
  [ -r "$node" ] || { echo ""; return; }
  v="$(cat "$node" 2>/dev/null)" || { echo ""; return; }
  # handle both "42000" (m°C) and "42" (°C) and also negatives if any
  case "$v" in
    ''|*[!0-9-]*) echo ""; return;;
  esac
  if [ "$v" -gt 1000 ] 2>/dev/null || [ "$v" -lt -1000 ] 2>/dev/null; then
    # milli-degC -> round toward zero
    echo $(( v / 1000 ))
  else
    echo "$v"
  fi
}

# Find zones whose type matches any of the provided (case-insensitive) patterns.
# Prints "zone_path|type" lines.
find_zones() {
  # patterns as regex alternation
  local patt="$1"
  for z in "$SCAN_ROOT"/thermal_zone*; do
    [ -d "$z" ] || continue
    local t
    t="$(tr '[:upper:]' '[:lower:]' < "$z/type" 2>/dev/null || true)"
    [ -n "$t" ] || continue
    echo "$t" | grep -Eiq "$patt" || continue
    printf "%s|%s\n" "$z" "$t"
  done
}

# Pick the "best" GPU zone (first match among common names).
pick_gpu_zone() {
  # Common labels by vendor:
  # qcom: "gpu-thermal", "gpu", "tsens_tz_sensorX" sometimes generic
  # mtk:  "mtktsgpu", "gpu"
  # exynos: "gpu-therm"
  # rockchip: "gpu_thermal"
  local gpu_re='(^|\b)(gpu-?thermal|gpu_?therm|gpu|mtktsgpu|g3d)(\b|$)'
  find_zones "$gpu_re" | head -n1 | cut -d'|' -f1
}

# Collect CPU zones (can be multiple, we’ll use max).
pick_cpu_zones() {
  # Lots of variations: cpu-thermal, cpu, big, little, a55/a78, tcpu*,
  # qcom tsens: "cpu-therm", "apc1-cpu0-usr", etc. MTK: "mtktscpu"
  local cpu_re='(^|\b)(cpu-?thermal|cpu(_[0-9]+)?|little|big|a[0-9]+|apc[0-9]+|mtktscpu|ap-therm|soc|cluster)(\b|$)'
  find_zones "$cpu_re" | cut -d'|' -f1 | sort -u
}

# Read max °C over a list of zones
max_temp_over() {
  local max=  t  path
  for path in "$@"; do
    t="$(read_temp_c "$path/temp")"
    [ -z "$t" ] && continue
    if [ -z "$max" ] || [ "$t" -gt "$max" ]; then max="$t"; fi
  done
  echo "${max:-}"
}

# --- discovery -------------------------------------------------------------

# Allow manual override via env (full paths to thermal_zoneX)
CPU_ZONES_OVERRIDE="${CPU_ZONES_OVERRIDE:-}"
GPU_ZONE_OVERRIDE="${GPU_ZONE_OVERRIDE:-}"

if [ -n "$CPU_ZONES_OVERRIDE" ]; then
  IFS=' ' read -r -a CPU_ZONES <<EOF
$CPU_ZONES_OVERRIDE
EOF
else
  mapfile -t CPU_ZONES <<EOF
$(pick_cpu_zones)
EOF
fi

if [ -n "$GPU_ZONE_OVERRIDE" ]; then
  GPU_ZONE="$GPU_ZONE_OVERRIDE"
else
  GPU_ZONE="$(pick_gpu_zone)"
fi

# Fallbacks: if we found nothing, just take all zones and hope for the best
if [ "${#CPU_ZONES[@]}" -eq 0 ]; then
  mapfile -t CPU_ZONES <<EOF
$(ls -d "$SCAN_ROOT"/thermal_zone* 2>/dev/null)
EOF
fi
[ -n "$GPU_ZONE" ] || GPU_ZONE="$(ls -d "$SCAN_ROOT"/thermal_zone* 2>/dev/null | head -n1)"

echo "[fan] CPU_ZONES=${CPU_ZONES[*]}" >&2
echo "[fan] GPU_ZONE=$GPU_ZONE" >&2

# --- control loop ---------------------------------------------------------

while :; do
  # Max across all CPU zones (so either cluster heating triggers)
  cpu_max="$(max_temp_over "${CPU_ZONES[@]}")"
  gpu_c="$(read_temp_c "$GPU_ZONE/temp")"

  if [ -z "$cpu_max" ] || [ -z "$gpu_c" ]; then
    echo "[$(date +%T)] ERROR: unable to read temps cpu='$cpu_max' gpu='$gpu_c'" >&2
    sleep "$INTERVAL"; continue
  fi

  # CPU bands: <55 → off, 55–65 → cool, >65 → max
  if   [ "$cpu_max" -gt 65 ]; then cpu_mode="max"
  elif [ "$cpu_max" -gt 55 ]; then cpu_mode="cool"
  else                            cpu_mode="off"
  fi

  # GPU bands: <45 → off, 45–55 → cool, >55 → max
  if   [ "$gpu_c" -gt 55 ]; then gpu_mode="max"
  elif [ "$gpu_c" -gt 45 ]; then gpu_mode="cool"
  else                           gpu_mode="off"
  fi

  # Combine priority: max > cool > off
  if [ "$cpu_mode" = "max" ] || [ "$gpu_mode" = "max" ]; then
    desired="max"
  elif [ "$cpu_mode" = "cool" ] || [ "$gpu_mode" = "cool" ]; then
    desired="cool"
  else
    desired="off"
  fi

  if [ "$last_mode" != "$desired" ]; then
    setprop "$PROP_NAME" "$desired"
    echo "[$(date +%T)] CPUmax=${cpu_max}°C GPU=${gpu_c}°C → $PROP_NAME=$desired"
    last_mode="$desired"
  fi

  sleep "$INTERVAL"
done

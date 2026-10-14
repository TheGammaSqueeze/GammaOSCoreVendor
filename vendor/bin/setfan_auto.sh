#!/system/bin/sh
# GammaOS RP Duo Lite fan, auto mode: a continuous curve from the hottest CPU or GPU
# zone to the PWM duty, with hysteresis at the bottom and a rate limit so the fan never
# jumps. The fan is a gpio5_pwm (TLMM gpio45 on the GP1 clock, gpio1 enable),
# /sys/class/gpio5_pwm2: state 0/1, duty and period in ns (period 50000 = 20 kHz).
#
# Curve (degrees C on the smoothed hottest zone):
#   below T_OFF           fan off
#   T_ON .. T_FULL        duty rises linearly from MIN_PCT to 100
#   above T_FULL          100
# The fan starts once the temperature reaches T_ON and stops only when it has fallen
# to T_OFF (hysteresis), and it starts at MIN_PCT, the lowest duty that spins it
# reliably and the same level as the cool mode. The temperature is a moving average
# over AVG_SAMPLES ticks and the duty moves at most STEP_PCT per tick towards its
# target, so a brief load spike raises the fan slowly and a drop lets it wind down
# slowly. With the thermal caps lifted the SoC sits at 55 to 62 C just navigating a
# menu (the GPU clocks up for the UI) and 65 to 75 C in play, so the fan stays off
# for menus and climbs through play.
T_OFF=${T_OFF:-63}
T_ON=${T_ON:-68}
T_FULL=${T_FULL:-85}
MIN_PCT=${MIN_PCT:-25}
STEP_PCT=${STEP_PCT:-2}
AVG_SAMPLES=${AVG_SAMPLES:-5}
SLEEP_SECS=${SLEEP_SECS:-2}
PROP_NAME="persist.gammaos.fan_mode_auto"
FAN=/sys/class/gpio5_pwm2
MONITOR_ONLY="${MONITOR_ONLY:-0}"
THERM_BASE="/sys/class/thermal"

on_exit() { exit 0; }
trap on_exit INT TERM

raw_to_c() {
  raw="$1"
  case "$raw" in ''|*[!0-9-]*) return 1 ;; esac
  [ "$raw" -gt 0 ] || return 1
  if [ "$raw" -ge 1000 ]; then c=$(( (raw + 500) / 1000 )); else c="$raw"; fi
  [ "$c" -ge 1 ] && [ "$c" -le 125 ] || return 1
  echo "$c"
}

# Zones: the CPU cluster and core sensors plus the GPU sensor, nothing else (the
# board thermistors, modem, camera and video zones all sit on the same die but
# lag; the quiet-therm skin zone is what the throttling used to key on).
TEMP_FILES=""
for z in "$THERM_BASE"/thermal_zone*; do
  [ -f "$z/type" ] || continue
  IFS= read -r t < "$z/type" 2>/dev/null || continue
  case "$t" in
    cpuss-*|cpu-*|apss*|gpu|*gpuss*|*adreno*|*kgsl*) TEMP_FILES="$TEMP_FILES $z/temp" ;;
  esac
done
echo "zones:$TEMP_FILES"

hottest_c() {
  max=""
  for f in $TEMP_FILES; do
    IFS= read -r raw < "$f" 2>/dev/null || continue
    t="$(raw_to_c "$raw")" || continue
    if [ -z "$max" ] || [ "$t" -gt "$max" ]; then max="$t"; fi
  done
  [ -n "$max" ] || return 1
  echo "$max"
}

period="$(cat "$FAN/period" 2>/dev/null)"
[ -n "$period" ] || period=50000

set_duty_pct() {
  pct="$1"
  if [ "$MONITOR_ONLY" = "1" ]; then return 0; fi
  if [ "$pct" -le 0 ]; then
    echo 0 > "$FAN/state"
  else
    echo $(( period * pct / 100 )) > "$FAN/duty"
    echo 1 > "$FAN/state"
  fi
}

# Target duty for a temperature, given whether the fan is currently running.
target_pct() {
  t="$1"; running="$2"
  if [ "$running" = "1" ]; then
    [ "$t" -le "$T_OFF" ] && { echo 0; return; }
  else
    [ "$t" -lt "$T_ON" ] && { echo 0; return; }
  fi
  if [ "$t" -ge "$T_FULL" ]; then echo 100; return; fi
  if [ "$t" -le "$T_ON" ]; then echo "$MIN_PCT"; return; fi
  echo $(( MIN_PCT + (100 - MIN_PCT) * (t - T_ON) / (T_FULL - T_ON) ))
}

cur_pct=0
prop_state=""
samples=""
nsamples=0
set_duty_pct 0

while true; do
  if [ "$(getprop sys.screen.state 2>/dev/null)" = "off" ]; then
    if [ "$cur_pct" -ne 0 ]; then set_duty_pct 0; cur_pct=0; fi
    if [ "$prop_state" != "off" ]; then setprop "$PROP_NAME" off; prop_state=off; fi
    samples=""; nsamples=0
    sleep "$SLEEP_SECS"
    continue
  fi
  if t="$(hottest_c)"; then
    samples="${samples:+$samples }$t"
    nsamples=$((nsamples + 1))
    if [ "$nsamples" -gt "$AVG_SAMPLES" ]; then
      samples="${samples#* }"
      nsamples=$AVG_SAMPLES
    fi
    sum=0
    for s in $samples; do sum=$((sum + s)); done
    avg=$(( (sum + nsamples / 2) / nsamples ))
    running=0; [ "$cur_pct" -gt 0 ] && running=1
    want="$(target_pct "$avg" "$running")"
    # Rate limit: at most STEP_PCT per tick, except the start (straight to MIN_PCT so
    # the fan spins up cleanly) and the stop.
    if [ "$want" -eq 0 ]; then
      new=0
    elif [ "$cur_pct" -eq 0 ]; then
      new=$MIN_PCT
    elif [ "$want" -gt "$cur_pct" ]; then
      new=$((cur_pct + STEP_PCT)); [ "$new" -gt "$want" ] && new=$want
    elif [ "$want" -lt "$cur_pct" ]; then
      new=$((cur_pct - STEP_PCT)); [ "$new" -lt "$want" ] && new=$want
      [ "$new" -lt "$MIN_PCT" ] && new=$MIN_PCT
    else
      new=$cur_pct
    fi
    if [ "$new" -ne "$cur_pct" ]; then
      set_duty_pct "$new"
      cur_pct=$new
    fi
    if [ "$cur_pct" -eq 0 ]; then st=off; elif [ "$cur_pct" -ge 100 ]; then st=max; else st=cool; fi
    if [ "$st" != "$prop_state" ]; then setprop "$PROP_NAME" "$st"; prop_state=$st; fi
    [ "$MONITOR_ONLY" = "1" ] && echo "t=$t avg=$avg want=$want duty=$cur_pct"
  fi
  sleep "$SLEEP_SECS"
done

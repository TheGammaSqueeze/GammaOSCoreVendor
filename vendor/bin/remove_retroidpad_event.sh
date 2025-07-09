#!/system/bin/sh
until pgrep 'gammapad' >/dev/null; do sleep 2; done
awk -v prefix='/dev/input/' '
  /Retroid Pocket Controller/{f=1}
  f && /Handlers=/ {
    for(i=1;i<=NF;i++)
      if ($i ~ /event[0-9]+/) {
        match($i, /event[0-9]+/)
        print prefix substr($i, RSTART, RLENGTH)
      }
    f=0
  }
' /proc/bus/input/devices | xargs -r rm -f

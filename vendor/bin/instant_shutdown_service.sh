while true; do
  cmd=$(getprop sys.powerctl)
  case "$cmd" in
    shutdown*)  sleep 0.1; echo o >/proc/sysrq-trigger; break ;;
    reboot*)    sleep 0.1; echo b >/proc/sysrq-trigger; break ;;
  esac
  sleep 1
done


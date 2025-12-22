#!/system/bin/sh

setprop persist.gammaos.refresh.lock 0
sleep 1
settings put system default_refresh_rate 60
settings put system min_refresh_rate 60
settings put system peak_refresh_rate 60
settings put global low_power 0
settings put global match_content_frame_rate 0
cmd display set-user-preferred-display-mode 0 1920 1080 60
sleep 1

for i in $(seq 1 10); do setprop persist.gammaos.refresh.lock 0; sleep 0.5; done

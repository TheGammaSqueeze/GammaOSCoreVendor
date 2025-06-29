settings put secure sysui_qs_tiles internet,bt,performance,abxy,mappingeditor,fan,deepsleepmode,rotation,dpadAnalogToggle,analogsensitivity,analogdeadzone,analogcalibration,analogaxis,rightanalogaxis,dcdimmingemulation,retroarchmenubuttonoverride

launcheruser=$( stat -c "%U" /data/data/com.magneticchen.daijishou) && \
launchergroup=$( stat -c "%G" /data/data/com.magneticchen.daijishou) && \
tar -xzf /vendor/etc/daijisho.tar.gz -P -C / && \
chown -R $launcheruser:$launchergroup /data/data/com.magneticchen.daijishou

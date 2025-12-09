#!/system/bin/sh

sleep 10
until pm install /system/etc/magisk.apk; do sleep 1; done

sleep 10
until pm install /system/etc/magisk.apk; do sleep 1; done

sleep 10
until pm install /system/etc/magisk.apk; do sleep 1; done

sleep 10
until pm install /system/etc/magisk.apk; do sleep 1; done

setprop persist.gammaos.v1.2.migration 1

#!/system/bin/sh

# Ask Android to restore Wi-Fi using its existing saved networks.
# Recheck briefly in case a vendor service switches it off during startup.
enable_wifi() {
    if [ "$(settings get global airplane_mode_on)" = 1 ]; then
        return 0
    fi
    svc wifi enable
}

log -t IbizaWifiBoot "Restoring Wi-Fi after boot"
enable_wifi
for delay in 3 5 8; do
    sleep "$delay"
    if [ "$(settings get global wifi_on)" != 1 ]; then
        enable_wifi
    fi
done
log -t IbizaWifiBoot "wifi_on=$(settings get global wifi_on)"

#!/system/bin/sh
# This file is sourced by Jancar's preinstall service after boot_completed.
# Continue the original preinstall script after the governor change.
setprop jancar.preinstall.continue 1
governor_path=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
if [ -w "$governor_path" ]; then
    echo performance > "$governor_path"
fi

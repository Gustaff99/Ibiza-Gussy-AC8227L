#!/system/bin/sh
set -eu
wp=/sys/kernel/debug/mmc0/sw_wp_en
target=/vendor/etc/init/ibiza-boot-performance.rc
test -f "$target"
test "$(cat "$wp")" = 1
trap 'mount -o remount,ro /vendor; echo 1 > "$wp"' EXIT
echo 0 > "$wp"
test "$(cat "$wp")" = 0
mount -o remount,rw /vendor
rm "$target"
sync
echo interactive > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

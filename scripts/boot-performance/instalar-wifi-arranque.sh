#!/system/bin/sh
set -eu

staged=/data/local/tmp
rc=/vendor/etc/init/ibiza-wifi-arranque.rc
script=/vendor/bin/ibiza-wifi-arranque.sh
wp=/sys/kernel/debug/mmc0/sw_wp_en

test ! -e "$rc"
test ! -e "$script"
test "$(cat "$wp")" = 1
sh -n "$staged/ibiza-wifi-arranque.sh"
trap 'mount -o remount,ro /vendor; echo 1 > "$wp"' EXIT
echo 0 > "$wp"
test "$(cat "$wp")" = 0
mount -o remount,rw /vendor

cp "$staged/ibiza-wifi-arranque.sh" "$script"
chown 0:0 "$script"
chmod 0644 "$script"
restorecon "$script"

cp "$staged/ibiza-wifi-arranque.rc" /vendor/etc/ibiza-wifi-arranque.rc.tmp
chown 0:0 /vendor/etc/ibiza-wifi-arranque.rc.tmp
chmod 0644 /vendor/etc/ibiza-wifi-arranque.rc.tmp
mv /vendor/etc/ibiza-wifi-arranque.rc.tmp "$rc"
restorecon "$rc"
sync
sha256sum "$script" "$rc"

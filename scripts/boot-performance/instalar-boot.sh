#!/system/bin/sh
set -eu
target=/vendor/etc/init/ibiza-boot-performance.rc
staged=/data/local/tmp/ibiza-boot-performance.rc
temporary=/vendor/etc/ibiza-boot-performance.rc.tmp
wp=/sys/kernel/debug/mmc0/sw_wp_en
test ! -e "$target"
test "$(cat "$wp")" = 1
trap 'mount -o remount,ro /vendor; echo 1 > "$wp"' EXIT
echo 0 > "$wp"
test "$(cat "$wp")" = 0
mount -o remount,rw /vendor
cp "$staged" "$temporary"
chown 0:0 "$temporary"
chmod 0644 "$temporary"
mv "$temporary" "$target"
restorecon "$target"
sync
sha256sum "$target"
ls -lZ "$target"

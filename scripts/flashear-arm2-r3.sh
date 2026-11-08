#!/system/bin/sh
set -eu

partition=/dev/block/mmcblk0p9
wp=/sys/kernel/debug/mmc0/sw_wp_en
original=/data/local/tmp/ibiza-arm2-original.bin
candidate=/data/local/tmp/ibiza-arm2-r3.bin
stock_hash=679bb2274f50a9d2b99b840003284a9a7063674fd6fecc272d0652b25a6eba14
candidate_hash=74933039931544fd57f86a21f2d3adb1e948b852e5db1f617751e85865e0752a

digest() {
    sha256sum "$1" | cut -d ' ' -f 1
}

test "$(id -u)" = 0
test "$(getprop ro.boot.hardware)" = ac8227l
grep -qx PARTNAME=ARM2 /sys/class/block/mmcblk0p9/uevent
test "$(cat /sys/class/block/mmcblk0p9/size)" = 8192
test "$(cat "$wp")" = 1
test "$(wc -c < "$original")" = 4194304
test "$(wc -c < "$candidate")" = 4194304
test "$(digest "$original")" = "$stock_hash"
test "$(digest "$candidate")" = "$candidate_hash"
test "$(digest "$partition")" = "$stock_hash"

trap 'echo 1 > "$wp"' EXIT
echo 0 > "$wp"
test "$(cat "$wp")" = 0

write_and_verify() {
    dd if="$1" of="$partition" bs=4096 count=1024 && sync &&
        test "$(digest "$partition")" = "$2"
}

if ! write_and_verify "$candidate" "$candidate_hash"; then
    echo "La escritura r3 no se verificó. Restaurando ARM2 original." >&2
    if write_and_verify "$original" "$stock_hash"; then
        echo "ARM2 original restaurado y verificado." >&2
        exit 1
    fi
    echo "La restauración no se pudo verificar." >&2
    exit 2
fi

echo 1 > "$wp"
test "$(cat "$wp")" = 1
trap - EXIT
sha256sum "$partition"

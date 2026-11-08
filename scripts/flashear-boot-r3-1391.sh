#!/system/bin/sh
set -eu

partition=/dev/block/mmcblk0p10
arm2=/dev/block/mmcblk0p9
wp=/sys/kernel/debug/mmc0/sw_wp_en
original=/data/local/tmp/ibiza-boot-original.img
candidate=/data/local/tmp/ibiza-boot-r3-1391.img
stock_hash=8911ad0e01bf9e229d76eeb5d43ee117e793553192458c69108c144dcd66dc57
candidate_hash=c5a00efe7ce94dfcdc2b1a0a73bb658ce287b5a6af5cf1704e15b5bda26f388a
arm2_hash=74933039931544fd57f86a21f2d3adb1e948b852e5db1f617751e85865e0752a

digest() {
    sha256sum "$1" | cut -d ' ' -f 1
}

test "$(id -u)" = 0
test "$(getprop ro.boot.hardware)" = ac8227l
grep -qx PARTNAME=BOOTIMG /sys/class/block/mmcblk0p10/uevent
grep -qx PARTNAME=ARM2 /sys/class/block/mmcblk0p9/uevent
test "$(cat /sys/class/block/mmcblk0p10/size)" = 32768
test "$(cat "$wp")" = 1
test "$(wc -c < "$original")" = 16777216
test "$(wc -c < "$candidate")" = 16777216
test "$(digest "$original")" = "$stock_hash"
test "$(digest "$candidate")" = "$candidate_hash"
test "$(digest "$partition")" = "$stock_hash"
test "$(digest "$arm2")" = "$arm2_hash"

trap 'echo 1 > "$wp"' EXIT
echo 0 > "$wp"
test "$(cat "$wp")" = 0

write_and_verify() {
    dd if="$1" of="$partition" bs=4096 count=4096 && sync &&
        test "$(digest "$partition")" = "$2"
}

if ! write_and_verify "$candidate" "$candidate_hash"; then
    echo "La escritura r3 no se verificó. Restaurando BOOTIMG original." >&2
    if write_and_verify "$original" "$stock_hash"; then
        echo "BOOTIMG original restaurado y verificado." >&2
        exit 1
    fi
    echo "La restauración no se pudo verificar." >&2
    exit 2
fi

echo 1 > "$wp"
test "$(cat "$wp")" = 1
trap - EXIT
sha256sum "$partition" "$arm2"

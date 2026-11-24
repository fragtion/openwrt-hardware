#!/bin/sh
# Build a full 4 MiB SPI image: stock u-boot + u-boot-env + factory (0x0-0x4ffff) from a flash
# dump, then the 19.07.10 sysupgrade image (fwtool metadata stripped) at 0x50000, padded with 0xff.
# Usage: mkflashdump.sh <workdir> <dump-with-bootloader-and-factory.bin>
set -e
W=$1; STOCK=$(cd "$(dirname "$2")" && pwd)/$(basename "$2"); cd "$W"
IB=$(ls -d openwrt-imagebuilder-19.07.10-*/ | head -1); IB=$(cd "$IB" && pwd)
BIN=$IB/bin/targets/ramips/rt305x
SYSUP=$BIN/openwrt-19.07.10-ramips-rt305x-a6-squashfs-sysupgrade.bin
OUT=$BIN/flashdump-openwrt-19.07.10-ramips-rt305x-a6-squashfs.bin
FW=$W/kwork/fw-nometa.bin

cp "$SYSUP" "$FW"
$IB/staging_dir/host/bin/fwtool -q -t -i /dev/null "$FW"
[ "$(stat -c %s "$FW")" -le $((0x3b0000)) ] || { echo "firmware too big"; exit 1; }

head -c $((0x50000)) "$STOCK" > "$OUT"
cat "$FW" >> "$OUT"
head -c $((0x400000 - $(stat -c %s "$OUT"))) /dev/zero | tr '\000' '\377' >> "$OUT"
ls -l "$OUT"

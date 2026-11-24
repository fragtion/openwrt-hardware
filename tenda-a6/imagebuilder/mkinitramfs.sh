#!/bin/sh
# Build a6-initramfs-kernel.bin from the official 19.07.10 vmlinux-initramfs (KERNEL_INITRAMFS
# uses the same recipe as KERNEL). Verified first against the official 3G150B initramfs.
# Run mkkernel.sh first (it builds image-A6.dtb).
set -e
W=${1:-$PWD}; cd "$W"
IB=$(ls -d openwrt-imagebuilder-19.07.10-*/ | head -1); IB=$(cd "$IB" && pwd)
KDIR=$IB/build_dir/target-mipsel_24kc_musl/linux-ramips_rt305x
HOSTBIN=$IB/staging_dir/host/bin
WORK=$W/kwork; mkdir -p "$WORK"
URL=https://downloads.openwrt.org/releases/19.07.10/targets/ramips/rt305x
REF=openwrt-19.07.10-ramips-rt305x-3g150b-initramfs-kernel.bin
[ -f "$WORK/$REF" ] || wget -q -O "$WORK/$REF" "$URL/$REF"
grep "$REF" sha256sums | (cd "$WORK" && sha256sum -c -)

SOURCE_DATE_EPOCH=$(od -An -tu1 -j8 -N4 "$WORK/$REF" | awk '{print $1*16777216+$2*65536+$3*256+$4}')
export SOURCE_DATE_EPOCH

build() { # $1=dtb $2=out
	cp $KDIR/vmlinux-initramfs "$2"
	cat "$1" >> "$2"
	$HOSTBIN/lzma e "$2" -lc1 -lp2 -pb2 "$2.new" && mv "$2.new" "$2"
	$HOSTBIN/mkimage -A mips -O linux -T kernel -C lzma -a 0x80000000 -e 0x80000000 \
		-n 'Linux Kernel Image' -d "$2" "$2.new" >/dev/null && mv "$2.new" "$2"
}

build $KDIR/image-3G150B.dtb "$WORK/3g150b-initramfs.bin"
cmp "$WORK/3g150b-initramfs.bin" "$WORK/$REF" || { echo "initramfs recipe MISMATCH"; exit 1; }
echo "recipe verified: 3G150B initramfs identical to official"

OUT=$IB/bin/targets/ramips/rt305x/openwrt-19.07.10-ramips-rt305x-a6-initramfs-kernel.bin
mkdir -p "$(dirname "$OUT")"
build $KDIR/image-A6.dtb "$OUT"
ls -l "$OUT"

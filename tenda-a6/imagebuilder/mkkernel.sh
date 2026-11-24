#!/bin/sh
# Build a6-kernel.bin inside the official 19.07.10 ImageBuilder exactly like the buildbot:
#   KERNEL := kernel-bin | append-dtb | lzma | uImage lzma
# The method is verified first by reproducing the official A5-V11 DTB and kernel byte-for-byte.
set -e
W=${1:-$PWD}; cd "$W"
IB=$(ls -d openwrt-imagebuilder-19.07.10-*/ | head -1); IB=$(cd "$IB" && pwd)
SDK=$(ls -d openwrt-sdk-19.07.10-*/ | head -1); SDK=$(cd "$SDK" && pwd)
KDIR=$IB/build_dir/target-mipsel_24kc_musl/linux-ramips_rt305x
LINUX_DIR=$KDIR/linux-4.14.275
# The IB lacks include/dt-bindings; the SDK ships the same official kernel tree with them.
SDK_LINUX=$SDK/build_dir/target-mipsel_24kc_musl/linux-ramips_rt305x/linux-4.14.275
DTS_DIR=$IB/target/linux/ramips/dts
HOSTBIN=$IB/staging_dir/host/bin
CPP=$(ls $SDK/staging_dir/toolchain-*/bin/mipsel-openwrt-linux-cpp | head -1)
WORK=$W/kwork; mkdir -p "$WORK"

# Official build timestamp, from the a5-v11 uImage header (bytes 8..11, big-endian)
SOURCE_DATE_EPOCH=$(od -An -tu1 -j8 -N4 $KDIR/a5-v11-kernel.bin | awk '{print $1*16777216+$2*65536+$3*256+$4}')
export SOURCE_DATE_EPOCH

build_dtb() { # $1=dts name  $2=out
	STAGING_DIR=$SDK/staging_dir $CPP -nostdinc -x assembler-with-cpp \
		-I$DTS_DIR -I$DTS_DIR/include -I$SDK_LINUX/include/ \
		-undef -D__DTS__ -o "$2.tmp" "$DTS_DIR/$1.dts"
	$LINUX_DIR/scripts/dtc/dtc -O dtb -i$DTS_DIR/ -o "$2" "$2.tmp"
	rm "$2.tmp"
}

build_kernel() { # $1=dtb  $2=out
	cp $KDIR/vmlinux "$2"
	cat "$1" >> "$2"
	$HOSTBIN/lzma e "$2" -lc1 -lp2 -pb2 "$2.new" && mv "$2.new" "$2"
	$HOSTBIN/mkimage -A mips -O linux -T kernel -C lzma -a 0x80000000 -e 0x80000000 \
		-n 'MIPS OpenWrt Linux-4.14.275' -d "$2" "$2.new" >/dev/null && mv "$2.new" "$2"
}

build_dtb A5-V11 "$WORK/A5-V11.dtb"
cmp "$WORK/A5-V11.dtb" $KDIR/image-A5-V11.dtb || { echo "DTB recipe MISMATCH"; exit 1; }
build_kernel $KDIR/image-A5-V11.dtb "$WORK/a5-v11-kernel.bin"
cmp "$WORK/a5-v11-kernel.bin" $KDIR/a5-v11-kernel.bin || { echo "kernel recipe MISMATCH"; exit 1; }
echo "recipe verified: A5-V11 DTB and kernel identical to official"

build_dtb A6 $KDIR/image-A6.dtb
build_kernel $KDIR/image-A6.dtb $KDIR/a6-kernel.bin
ls -l $KDIR/image-A6.dtb $KDIR/a6-kernel.bin

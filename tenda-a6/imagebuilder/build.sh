#!/bin/sh
# Build Tenda A6 images for OpenWrt 19.07.10 with the *official* ImageBuilder and the *official*
# kernel binary, so that kmods from downloads.openwrt.org install without vermagic errors.
#
# The ImageBuilder can only reuse prebuilt <device>-kernel.bin files, and the A6 is not an
# official device. So we compile the A6 DTB and append it to the official vmlinux exactly like
# the buildbot recipe does (kernel-bin | append-dtb | lzma | uImage lzma). The recipe is checked
# byte-for-byte against official A5-V11 / 3G150B artifacts before it is used.
#
# Usage:  ./build.sh [workdir]
# Env:    PACKAGES="..."   extra/removed packages for `make image` (default: official set)
#         FILES=dir        extra rootfs overlay (merged over the board files)
#         EXTRA_IMAGE_NAME=name
#
# Needs: a Linux x86_64 host with the usual OpenWrt ImageBuilder prerequisites, git, wget, xz.
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
W=$(mkdir -p "${1:-$PWD/a6-1907}" && cd "${1:-$PWD/a6-1907}" && pwd)
REL=19.07.10
URL=https://downloads.openwrt.org/releases/$REL/targets/ramips/rt305x
IBNAME=openwrt-imagebuilder-$REL-ramips-rt305x.Linux-x86_64
SDKNAME=openwrt-sdk-$REL-ramips-rt305x_gcc-7.5.0_musl.Linux-x86_64
cd "$W"

echo "== fetching official $REL ImageBuilder + SDK"
for f in sha256sums config.buildinfo feeds.buildinfo version.buildinfo $IBNAME.tar.xz $SDKNAME.tar.xz; do
	[ -f "$f" ] || wget -q "$URL/$f"
done
grep -E " \*?($IBNAME|$SDKNAME)\.tar\.xz$" sha256sums | sha256sum -c -
[ -d $IBNAME ] || tar -xJf $IBNAME.tar.xz
[ -d $SDKNAME ] || tar -xJf $SDKNAME.tar.xz

echo "== patching OpenWrt v$REL source tree"
if [ ! -d src ]; then
	git clone -q --depth 1 -b v$REL https://github.com/openwrt/openwrt.git src
	git -C src apply "$HERE/../openwrt-$REL-tenda-a6.patch"
fi

echo "== mirroring the A6 patch into the ImageBuilder"
"$HERE/ib_prep.sh" "$W"

echo "== building a6-kernel.bin / initramfs from the official vmlinux"
"$HERE/mkkernel.sh" "$W"
"$HERE/mkinitramfs.sh" "$W"

echo "== make image"
OVL=$W/files-build
rm -rf "$OVL"; mkdir -p "$OVL"
cp -a "$W/files/." "$OVL/"
[ -n "$FILES" ] && cp -a "$FILES/." "$OVL/"
# The IB prereq check insists on python3 distutils, which nothing in `make image` uses.
mkdir -p "$W/pyshim/distutils" && touch "$W/pyshim/distutils/__init__.py" "$W/pyshim/distutils/util.py"
PYTHONPATH=$W/pyshim make -C $IBNAME image PROFILE=a6 FILES="$OVL" \
	${EXTRA_IMAGE_NAME:+EXTRA_IMAGE_NAME=$EXTRA_IMAGE_NAME} PACKAGES="$PACKAGES"

ls -l $IBNAME/bin/targets/ramips/rt305x/

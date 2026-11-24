#!/bin/sh
# Mirror the A6 source patch (applied in $W/src) into the official 19.07.10 ImageBuilder:
#  - DTS + image recipe go into the IB tree,
#  - the patched base-files scripts (ramips.sh, 02_network) go into a FILES overlay,
#  - a DEVICE_a6 profile (cloned from the official A5-V11 entry) goes into .targetinfo.
set -e
W=${1:-$PWD}; cd "$W"
IB=$(ls -d openwrt-imagebuilder-19.07.10-*/ | head -1); IB=${IB%/}
SRC=src/target/linux/ramips

cp $SRC/dts/A6.dts $IB/target/linux/ramips/dts/A6.dts
cp $SRC/image/rt305x.mk $IB/target/linux/ramips/image/rt305x.mk

mkdir -p files/lib files/etc/board.d
cp $SRC/base-files/lib/ramips.sh files/lib/ramips.sh
cp $SRC/base-files/etc/board.d/02_network files/etc/board.d/02_network
chmod 755 files/etc/board.d/02_network

cd $IB
if ! grep -q '^Target-Profile: DEVICE_a6$' .targetinfo; then
python3 - <<'PY'
p = '.targetinfo'
s = open(p).read()
start = s.index('Target-Profile: DEVICE_a5-v11\n')
end = s.index('@@\n', start) + 3
blk = s[start:end]
blk = blk.replace('DEVICE_a5-v11', 'DEVICE_a6').replace('A5-V11', 'Tenda A6')
blk = blk.replace('Target-Profile-Default: n', 'Target-Profile-Default: y')
blk = blk.replace('a5-v11', 'a6')
open(p, 'w').write(s[:end] + blk + s[end:])
PY
fi
rm -f .profiles.mk
make info | grep -A3 '^a6:'

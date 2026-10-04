#!/bin/sh
# Builds Q16.LDG, the zView codec, and test/ZVTEST.PRG.
#
# Needs m68k-atari-mint-gcc with the ldg package (cross-mint-essential and
# ldg-m68k-atari-mint from https://launchpad.net/~vriviere/+archive/ubuntu/ppa)
# and two headers from zView (imginfo.h and txt_data.h, GPL). They are
# downloaded from GitHub unless a zView source tree is given.
#
# Usage: build.sh [zview source directory]

set -e
cd "$(dirname "$0")"

if [ -n "$1" ]; then
	ZVINC="$1/zview/plugins/common"
else
	ZVINC=zview-include
	mkdir -p $ZVINC
	for f in imginfo.h txt_data.h; do
		[ -f $ZVINC/$f ] || curl -sSL -o $ZVINC/$f https://raw.githubusercontent.com/th-otto/zview/master/zview/plugins/common/$f
	done
fi

CFLAGS="-m68000 -O2 -std=gnu99 -Wall -I$ZVINC -I../.."

m68k-atari-mint-gcc $CFLAGS -o Q16.LDG q16codec.c ../../q16_lib.c -lldg -Wl,--stack,16k
m68k-atari-mint-strip Q16.LDG
m68k-atari-mint-gcc $CFLAGS -o test/ZVTEST.PRG test/zvtest.c -lldg -lgem
echo "Built Q16.LDG ($(wc -c < Q16.LDG) bytes) and test/ZVTEST.PRG"

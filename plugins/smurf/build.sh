#!/bin/sh
# Builds the Smurf modules Q16.SIM (import) and Q16.SXM (export), and
# test/SMURFTST.TOS.
#
# Needs m68k-atari-mint-gcc (https://launchpad.net/~vriviere/+archive/ubuntu/ppa),
# vasm (http://sun.hasenbraten.de/vasm/, CPU=m68k SYNTAX=mot) and six
# headers from Smurf (GPL). They are downloaded from GitHub unless a Smurf
# source tree is given.
#
# Usage: build.sh [smurf source directory] [vasm executable]

set -e
cd "$(dirname "$0")"

if [ -n "$1" ]; then
	SMINC="$1/include"
else
	SMINC=smurf-include
	mkdir -p $SMINC
	for f in import.h smurfine.h portab.h stdint_.h sym_gem.h dit_mod.h; do
		[ -f $SMINC/$f ] || curl -sSL -o $SMINC/$f https://raw.githubusercontent.com/th-otto/smurf/master/include/$f
	done
fi
VASM=${2:-vasmm68k_mot}

CFLAGS="-m68000 -O2 -fomit-frame-pointer -std=gnu99 -Wall -I$SMINC -I../.."

$VASM -quiet -devpac -Faout -o impstart.o impstart.s > /dev/null
$VASM -quiet -devpac -Faout -o expstart.o expstart.s > /dev/null
m68k-atari-mint-gcc $CFLAGS -s -nostartfiles -o Q16.SIM impstart.o q16imp.c ../../q16_lib.c -lgem
m68k-atari-mint-gcc $CFLAGS -s -nostartfiles -o Q16.SXM expstart.o q16exp.c ../../q16_lib.c -lgem
m68k-atari-mint-gcc $CFLAGS -o test/SMURFTST.TOS test/smurftst.c
rm -f impstart.o expstart.o
echo "Built Q16.SIM ($(wc -c < Q16.SIM) bytes), Q16.SXM ($(wc -c < Q16.SXM) bytes) and test/SMURFTST.TOS"

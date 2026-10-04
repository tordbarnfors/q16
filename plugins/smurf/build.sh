#!/bin/sh
# Builds the Smurf modules Q16.SIM (import) and Q16.SXM (export), and
# test/SMURFTST.TOS, and the same for Pure C Smurf (purec/, test/SMURFTPC.TOS).
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

# For Smurf built with gcc.
$VASM -quiet -devpac -Faout -o impstart.o impstart.s > /dev/null
$VASM -quiet -devpac -Faout -o expstart.o expstart.s > /dev/null
m68k-atari-mint-gcc $CFLAGS -s -nostartfiles -o Q16.SIM impstart.o q16imp.c ../../q16_lib.c -lgem
m68k-atari-mint-gcc $CFLAGS -s -nostartfiles -o Q16.SXM expstart.o q16exp.c ../../q16_lib.c -lgem

# For Smurf built with Pure C (the original Smurf 1.06 binaries).
mkdir -p purec
$VASM -quiet -devpac -Faout -DPUREC_SMURF=1 -o impstart.o impstart.s > /dev/null
$VASM -quiet -devpac -Faout -DPUREC_SMURF=1 -o expstart.o expstart.s > /dev/null
m68k-atari-mint-gcc $CFLAGS -DPUREC_SMURF -s -nostartfiles -o purec/Q16.SIM impstart.o q16imp.c ../../q16_lib.c -lgem
m68k-atari-mint-gcc $CFLAGS -DPUREC_SMURF -s -nostartfiles -o purec/Q16.SXM expstart.o q16exp.c ../../q16_lib.c -lgem

# Test program, also in a version calling the modules like Pure C Smurf.
$VASM -quiet -devpac -Faout -o test/pccall.o test/pccall.s > /dev/null
m68k-atari-mint-gcc $CFLAGS -o test/SMURFTST.TOS test/smurftst.c
m68k-atari-mint-gcc $CFLAGS -DPUREC_CALLER -o test/SMURFTPC.TOS test/smurftst.c test/pccall.o
rm -f impstart.o expstart.o test/pccall.o
echo "Built Q16.SIM, Q16.SXM, purec/Q16.SIM, purec/Q16.SXM, test/SMURFTST.TOS and test/SMURFTPC.TOS"

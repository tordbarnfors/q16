#!/bin/sh
# Builds FALCBNCH.TOS.
#
# Needs m68k-atari-mint-gcc (https://launchpad.net/~vriviere/+archive/ubuntu/ppa),
# vasm (http://sun.hasenbraten.de/vasm/, built with CPU=m68k SYNTAX=mot) and
# zlib, libpng and libjpeg-turbo built for the 68030 by build_libs.sh.
#
# Usage: build.sh <libs prefix> [vasm executable]

set -e
cd "$(dirname "$0")"

PREFIX=${1:?usage: build.sh <libs prefix> [vasm executable]}
VASM=${2:-vasmm68k_mot}
# Code is compiled for the 68030 without FPU instructions and linked with the
# plain 68000 MiNTLib, as the 68020-60 MiNTLib needs an FPU.
CFLAGS="-m68030 -msoft-float -O2 -fomit-frame-pointer -std=gnu99 -Wall"

$VASM -quiet -devpac -m68030 -Faout -o q16dec.o ../m68k/q16dec.s
$VASM -quiet -devpac -m68030 -Faout -o natfeats.o natfeats.s
m68k-atari-mint-gcc $CFLAGS -I"$PREFIX/include" -c falcbench.c q16lib_c.c
m68k-atari-mint-gcc -m68000 falcbench.o q16lib_c.o q16dec.o natfeats.o \
	-L"$PREFIX/lib" -lpng -lz -ljpeg -lm -o FALCBNCH.TOS
m68k-atari-mint-strip FALCBNCH.TOS
rm -f falcbench.o q16lib_c.o q16dec.o natfeats.o

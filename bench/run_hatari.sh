#!/bin/sh
# Runs FALCBNCH.TOS on an emulated Atari Falcon in Hatari and prints the results.
#
# Usage: run_hatari.sh <EmuTOS 512k/1024k image> <image directory>
#
# The emulated machine is a stock Falcon: 68030 at 16 MHz, no FPU, 14 MB
# ST-RAM, no TT/Fast-RAM, VGA monitor. The CPU runs in cycle-exact mode.
# The image directory is mounted as drive C: and BENCH.TXT is written there.

set -e
cd "$(dirname "$0")"

TOS=${1:?usage: run_hatari.sh <EmuTOS image> <image directory>}
DIR=${2:?usage: run_hatari.sh <EmuTOS image> <image directory>}

cp FALCBNCH.TOS "$DIR/"
rm -f "$DIR/BENCH.TXT"

SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy hatari --machine falcon --tos "$TOS" \
	--cpulevel 3 --cpuclock 16 --cpu-exact yes --compatible yes --mmu no --fpu none --dsp none \
	--memsize 14 --ttram 0 --monitor vga --natfeats yes --fast-forward yes --fast-boot yes --sound off \
	--harddrive "$DIR" --auto 'C:\FALCBNCH.TOS' --confirm-quit no --run-vbls 2000000 > "$DIR/hatari.log" 2>&1 || true

tr -d '\r' < "$DIR/BENCH.TXT"

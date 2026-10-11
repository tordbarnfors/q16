#!/bin/sh
# Assembles shower.s into SHOWER.TTP with vasm in Devpac mode.
#
# Usage: build.sh [vasm executable] [original SHOWER.TTP to compare with]

set -e
cd "$(dirname "$0")"

VASM=${1:-vasmm68k_mot}

$VASM -quiet -devpac -Ftos -o SHOWER.TTP shower.s > /dev/null
echo "Built SHOWER.TTP ($(wc -c < SHOWER.TTP) bytes)"

if [ -n "$2" ]; then
	cmp SHOWER.TTP "$2" && echo "Identical to $2"
fi

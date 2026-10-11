#!/bin/sh
# Builds Q16.GVL and Q16.GVS, the GEM-View load and save modules, with vasm
# in Devpac mode.
#
# Usage: build.sh [vasm executable]

set -e
cd "$(dirname "$0")"
${1:-vasmm68k_mot} -quiet -devpac -Ftos -o Q16.GVL q16.s > /dev/null
${1:-vasmm68k_mot} -quiet -devpac -Ftos -o Q16.GVS q16save.s > /dev/null
echo "Built Q16.GVL ($(wc -c < Q16.GVL) bytes) and Q16.GVS ($(wc -c < Q16.GVS) bytes)"

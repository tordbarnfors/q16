#!/bin/sh
# Builds Q16.GVL, the GEM-View load module, with vasm in Devpac mode.
#
# Usage: build.sh [vasm executable]

set -e
cd "$(dirname "$0")"
${1:-vasmm68k_mot} -quiet -devpac -Ftos -o Q16.GVL q16.s > /dev/null
echo "Built Q16.GVL ($(wc -c < Q16.GVL) bytes)"

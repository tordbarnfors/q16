# Shower 1.2

Shower is a fast picture viewer for the Atari Falcon written in assembly by
Blade of New Core (Tord Jansson) in 1995. See [SHOWER.TXT](SHOWER.TXT) for the
original documentation.

The source code of version 1.1 was lost, so `shower.s` was recreated by
disassembling SHOWER.TTP 1.1 (from
[fujiology.org](https://fujiology.org/FALCON/NEW_CORE/SHOWER11.ZIP), see
[demozoo](https://demozoo.org/productions/96025/)) with
[rg-dis](https://www.reservoir-gods.com/tools/rg-dis/) 0.9.40 by Reservoir Gods
in Devpac 3 dialect. That disassembly re-assembled to a byte-identical
SHOWER.TTP and is the first commit of `shower.s`.

Version 1.2 adds support for Q16 pictures (`.Q16`):

* The format table has a new entry with a header parser (`Q16_HEADER`) and a
  loader (`Q16_LOAD`), following the same pattern as the Targa support.
* The picture is decoded by `m68k/q16dec.s`, which is included into the
  source, into a temporary buffer and copied to the screen.
* Pictures with alpha are blended against black.

Labels from the disassembly (`_Lxxxx`, `_Dxxxx`, `_Bxxxx`) are kept as they
are, apart from the few rg-dis named itself.

## Building

    ./build.sh path/to/vasmm68k_mot

builds SHOWER.TTP with [vasm](http://sun.hasenbraten.de/vasm/) in Devpac mode.
Give the original SHOWER.TTP as a second argument to compare with it (only
useful for the version 1.1 source).

Devpac 3 should also be able to assemble it, but that hasn't been tested.

## Testing

Tested in Hatari 2.4.1 (Falcon, 68030, EmuTOS 1.3) on VGA and RGB monitors
with Q16 pictures with and without alpha, comparing with the same pictures as
Targa files. Targa and GIF files display identically in versions 1.1 and 1.2.

## Credits

The GIF depacker in Shower is taken from TurboGIF by Sascha Springer.

`test/` has the tools used for testing: `launch.s` assembles to LAUNCH.TOS,
which runs a program with a command line in Hatari, and `showtest.py` runs
Hatari, takes a screenshot of what's displayed and quits.

## Known issues

* Uncompressed Targa files with a width that isn't a multiple of 16 pixels
  are displayed skewed, as the Targa loader reads lines of the width rounded
  up to 16 pixels. This bug is in version 1.1 too and hasn't been changed.
* Interlaced GIF files aren't displayed correctly (also in version 1.1).

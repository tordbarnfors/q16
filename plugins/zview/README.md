# Q16 codec for zView

[zView](https://github.com/th-otto/zview) is an image viewer for Atari
computers that uses codec plugins. `Q16.LDG` is a codec that lets zView
display Q16 pictures and save pictures as Q16.

* Decoding gives zView 24-bit RGB (RGB565 expanded by repeating the high
  bits). Pictures with alpha are blended against zView's background color.
* Encoding converts zView's 24-bit RGB to RGB565 (no alpha) and writes the
  Q16 file when the last line has been received.
* Uses q16_lib.c and is built for the 68000, so it runs on all Ataris. The
  table-less pixel functions are used and q16_lib.c is compiled with
  `Q16_NO_STATIC_TABLE`, which leaves the table versions out.
* About 5.5 KB: it's linked without a C library. `ldgstart.s` is the startup
  code (shrinks the memory block, calls `main()`), and `ldgmini.c` has the
  library side of the LDG protocol (`ldg_init()`) and the few string
  functions the codec needs. All other system calls are GEMDOS traps.

## Installing

Copy `Q16.LDG` into the `codecs` folder in zView's folder.

## Building

    ./build.sh [zview source directory] [vasm executable]

needs m68k-atari-mint-gcc (`cross-mint-essential` from
[Vincent Rivière's PPA](https://launchpad.net/~vriviere/+archive/ubuntu/ppa))
and [vasm](http://sun.hasenbraten.de/vasm/). The codec only uses `ldg.h` from
the LDG package (`ldg-m68k-atari-mint`); the test program links with the LDG
library.
zView's `imginfo.h` and `txt_data.h` are downloaded from GitHub unless a zView
source tree is given.

## Testing

`test/zvtest.c` loads the codec the same way zView does (`ldg_open()`,
`ldg_find()`), decodes a picture to a file of 24-bit RGB lines and encodes
those lines into a new Q16 file. It reads the file names from `ZVTEST.CFG`.

Tested in Hatari (Falcon, EmuTOS): the decoded lines match a reference
decoder for pictures with and without alpha, and a picture without alpha
re-encodes to a byte-identical file, both with the original 120 KB build
(MiNTLib) and the current 6 KB one. zView itself hasn't been tested, as no
zView binary was available.

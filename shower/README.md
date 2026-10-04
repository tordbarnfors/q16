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

It also fixes bugs found in version 1.1 (see the history in SHOWER.TXT):

* Targa: the loader (`_L0FC4`, `_L100A`) is rewritten. Version 1.1 skewed
  pictures with a width that isn't a multiple of 16 pixels, showed
  bottom-up pictures (the default origin) upside down, converted
  uncompressed 16-bit pixels wrongly (`ADD.W D1,D0` instead of
  `ADD.W D0,D0`), read the color map length as big endian and let RLE
  packets run past the picture. RLE pictures are now unpacked into a buffer
  of their own and converted like uncompressed ones, and 32-bit pictures
  are supported.
* GIF: interlaced pictures were shown as four stacked bands; the header
  parser didn't skip extension blocks, so most GIF89a files were rejected;
  the conversion loop ran over the screen height instead of the picture
  height, reading past the unpacked picture and writing past the screen,
  and converted whole screen lines instead of the picture width.
  Interlaced pictures are unpacked into a buffer of their own, as their
  lines are converted out of order.
* BMP (documented as "still buggy" in 1.1): every colour took its red
  component from the previous palette entry, lines were read with the width
  rounded down to 16 pixels instead of the padded BMP line length, the
  palette was assumed after a 40-byte info header, and compressed or
  non-256-colour files weren't rejected. Top-down BMP files are supported.

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
with Q16 pictures with and without alpha.

`test/regress.py` is a regression test: it shows each picture made by
`test/mkimages.py` (Targa in 16/24/32 bits, uncompressed and RLE, both
origins; GIF87a, interlaced and GIF89a; BMP bottom-up and top-down; Q16;
odd sizes and pictures larger than the screen) in Hatari on a VGA monitor
and compares the screen pixel by pixel with the expected picture:

    python3 test/mkimages.py pics path/to/gen_q16
    EMUTOS=etos1024k.img python3 test/regress.py SHOWER.TTP pics results

Version 1.2 passes all 21 pictures. Before these fixes, all Targa and BMP
pictures, the interlaced GIF and the GIF89a picture failed.

## Credits

The GIF depacker in Shower is taken from TurboGIF by Sascha Springer.

`test/` has the tools used for testing: `launch.s` assembles to LAUNCH.TOS,
which runs a program with a command line in Hatari, `showtest.py` runs
Hatari, takes a screenshot of what's displayed and quits, and `mkimages.py`
and `regress.py` are the regression test.

## Known issues

* 32-bit Targa pictures are shown without their alpha channel, unlike Q16
  pictures, which are blended against black.

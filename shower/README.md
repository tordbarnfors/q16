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

* The format table has a new entry with a header parser (`q16_header`) and a
  loader (`q16_load`), following the same pattern as the Targa support.
* The picture is decoded by `q_decPix()` and `q_decAlp()` from
  `m68k/q16dec.s`, which is included into the source, into temporary buffers
  and copied to the screen. `q_decPix()` needs no 64 KB table: for one
  picture, setting up the table would take longer than it saves (see
  [../bench](../bench/README.md#static-table-or-hash-formula)).
* Pictures with alpha are blended against black.

It also fixes bugs found in version 1.1 (see the history in SHOWER.TXT):

* Targa: the loader (`tga_header`, `tga_load`) is rewritten. Version 1.1 skewed
  pictures with a width that isn't a multiple of 16 pixels, showed
  bottom-up pictures (the default origin) upside down, converted
  uncompressed 16-bit pixels wrongly (`add.w d1,d0` instead of
  `add.w d0,d0`), read the color map length as big endian and let RLE
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
* Found while naming the labels:
  * IMG files without an XIMG palette got only the first few colours of the
    system palette (`img_palette` looped with `dbra d1`, the number of
    planes, instead of `dbra d0`).
  * `pi5_load` copied half of a 640 x 480 picture in 256 colours, as its
    `dbra` counter can't count to 76800 long words.
  * `pc1_load` unpacked each line over `line_source` and the variables
    after it (`lea` instead of `movea.l`). It happened to work.
  * `raw_header` wrote the 32-bit `raw_pixels` into a 16-bit variable,
    overwriting `img_line_bytes`. Also harmless in practice.
* Found by the tests for those: POV raw and IndyPaint pictures with a width
  that isn't a multiple of 16 lost their first 16 columns to the border, as
  their header parsers didn't round the width up like the others, and the
  POV raw loader could corrupt the first pixels (an uncleared register).

## Labels

The disassembly had numbered labels (`_L0FC4`, `_D2BEA`, `_B32C4`). They
have been replaced by names that say what the code or variable is for
(`tga_header`, `file_buffer`, `file_size`), with the help of the source of
an earlier Shower version, and every function and variable has a short
description. Labels inside a function are local (they start with a dot,
Devpac style), so only functions, variables and tables are global. A few
numbered labels were offsets into a neighbouring variable and are now
written as such, for example `screen+1` for the second byte of `screen`.

The code is in lower case (mnemonics, registers, hex numbers) and laid out
for a tab width of 4: operands in column 12, comments in column 48, and in
tables of variables and equates the mnemonic in column 20. The other
assembler sources (`m68k/`, the plugins) use the same layout.

The renaming was checked to use every local label only inside its own
function, and the result assembles to exactly the same SHOWER.TTP as
before. The internal labels of the shared decoder and encoder sources in
`m68k/` (the decoders are included into the source) are local too; the
GEM-View modules, the benchmark and Shower all built byte-identical to
before.

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
origins; GIF87a, interlaced and GIF89a; BMP bottom-up and top-down; Degas
PI1, PC1, PC2, PI4 and PI5; GEM IMG with 1 and 4 planes, with and without an
XIMG palette, using all IMG item types; POV raw; IndyPaint; Q16 with and
without alpha; odd sizes
and pictures larger than the screen) in Hatari on a VGA monitor and
compares the screen pixel by pixel with the expected picture:

    python3 test/mkimages.py pics path/to/gen_q16
    EMUTOS=etos1024k.img python3 test/regress.py SHOWER.TTP pics results

Version 1.2 passes all 32 pictures. Before the fixes, all Targa and BMP
pictures, the interlaced GIF, the GIF89a picture, the PI5 picture, the IMG
without a palette and the POV raw and IndyPaint pictures failed.

## Credits

The GIF depacker in Shower is taken from TurboGIF by Sascha Springer.

`test/` has the tools used for testing: `launch.s` assembles to LAUNCH.TOS,
which runs a program with a command line in Hatari, `showtest.py` runs
Hatari, takes a screenshot of what's displayed and quits, and `mkimages.py`
and `regress.py` are the regression test.

## Known issues

* 32-bit Targa pictures are shown without their alpha channel, unlike Q16
  pictures, which are blended against black.

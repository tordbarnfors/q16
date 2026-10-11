# Benchmarks

Compares decoding and encoding speed of Q16, PNG and JPEG on an Atari Falcon
(68030 at 16 MHz), emulated by Hatari, and encoding and decoding speed and file sizes
of Q16, QOI, PNG and JPEG on a PC (see [PC results](#pc-results)).

| Format | Decoder | Output |
|---|---|---|
| Q16 | `asm`: m68k/q16dec.s, `q_decPix()` | RGB565 (+ 8-bit alpha) |
| Q16 | `asmT`: m68k/q16dect.s, `q_decPxT()` with the static table | RGB565 (+ 8-bit alpha) |
| Q16 | `C`: q16_lib.c, `q16_decompressPixels()` | RGB565 (+ 8-bit alpha) |
| Q16 | `CT`: q16_lib.c, `q16_decompressPixelsT()` with the static table | RGB565 (+ 8-bit alpha) |
| PNG | `libpng`: libpng 1.6.44 + zlib 1.3.2 | 8-bit RGB(A) |
| PNG | `stb`: stb_image 2.30 | 8-bit RGB(A) |
| JPEG | `turbo`: libjpeg-turbo 3.0.1, default settings | 8-bit RGB |
| JPEG | `turbo565`: libjpeg-turbo 3.0.1, fast settings (IFAST DCT, no fancy upsampling) | RGB565 |
| JPEG | `stb`: stb_image 2.30 | 8-bit RGB |

All C code (benchmark, libraries and q16_lib.c) is compiled with
m68k-atari-mint-gcc 4.6.4 using `-m68030 -msoft-float -O2 -fomit-frame-pointer`,
except libjpeg-turbo which uses its default `-O3`. libjpeg-turbo has no SIMD
code for m68k and runs its portable C code. The program is linked with the
plain 68000 MiNTLib since the 68020-60 MiNTLib requires an FPU.

For each PNG file, the decoded pixels are also encoded with the same four
Q16 variants (`asm`: m68k/q16enc.s, `asmT`: m68k/q16enct.s, `C` and `CT`:
q16_lib.c), libpng (default compression, level 6) and libjpeg-turbo
(quality 90 and 75, not for the sprite sheet).

Each file is decoded from memory, repeatedly for at least two seconds. Timing
uses the 200 Hz system timer. The program also verifies that all four Q16
decoders give identical results, as do libpng and stb_image and all four Q16
encoders, and that each Q16 file decodes to exactly the same pixels as the
corresponding RGB565 PNG.

## Test images

`make_images.py` generates the image set: four photos from the Kodak test set
(kodim01, 03, 15 and 23, center cropped to 640x480), a 640x480 GUI style
screen and a 320x240 sprite sheet with alpha. Each image is saved as:

* `NAME.Q16` - Q16, lossless RGB565 (+ alpha).
* `NAME.PNG` - PNG of the image reduced to RGB565, i.e. exactly the same
  pixels as the Q16 file. This is the PNG that is benchmarked.
* `NAME_F.PNG` - PNG of the original full color image, for size comparison only.
* `NAME_90.JPG`, `NAME_75.JPG` - JPEG quality 90 and 75 (4:2:0), not for
  the sprite sheet since JPEG has no alpha.

PNG and JPEG files are written by Pillow (PNG with `optimize=True`).

## Running

Requirements: m68k-atari-mint-gcc from
[Vincent Rivière's PPA](https://launchpad.net/~vriviere/+archive/ubuntu/ppa)
(package `cross-mint-essential`), [vasm](http://sun.hasenbraten.de/vasm/)
(`make CPU=m68k SYNTAX=mot`), cmake, Hatari, an
[EmuTOS](https://emutos.sourceforge.io/) 1024k image, Python 3 with Pillow
and the Kodak images from <https://r0k.us/graphics/kodak/>.

    ./build_libs.sh ~/q16libs                       # zlib, libpng, libjpeg-turbo
    ./build.sh ~/q16libs path/to/vasmm68k_mot       # FALCBNCH.TOS
    ./make_images.py path/to/gen_q16 path/to/kodak images
    ./run_hatari.sh path/to/etos1024k.img images    # prints and writes images/BENCH.TXT
    ./make_table.py images                          # Markdown tables

`run_hatari.sh` emulates a stock Falcon: 68030 at 16 MHz in cycle-exact mode,
no FPU, no DSP, 14 MB ST-RAM, no TT/Fast-RAM, VGA monitor (640x480 in 4
bitplanes). FALCBNCH.TOS also runs on real hardware: put it in a folder with
the images and run it.

## Results

Measured in Hatari 2.4.1 with EmuTOS 1.3. Times are per decode of the
whole image. The photos and GUI are 640x480, the sprite sheet 320x240 with
alpha (Q16 time includes decoding the alpha channel).

### File sizes

| Image | Q16 | PNG (RGB565) | PNG (24/32-bit) | JPEG q90 | JPEG q75 |
|---|---|---|---|---|---|
| GUI | 40 KB | 30 KB | 41 KB | 55 KB | 39 KB |
| K01 | 358 KB | 379 KB | 610 KB | 120 KB | 72 KB |
| K03 | 249 KB | 274 KB | 409 KB | 58 KB | 33 KB |
| K15 | 307 KB | 302 KB | 482 KB | 73 KB | 41 KB |
| K23 | 299 KB | 255 KB | 444 KB | 63 KB | 34 KB |
| SPRITE | 55 KB | 30 KB | 37 KB | - | - |

### Decoding time

| Image | Q16 asm | Q16 asmT | Q16 C | Q16 CT | PNG libpng | PNG stb | JPEG q90 turbo | JPEG q90 turbo565 | JPEG q90 stb | JPEG q75 turbo | JPEG q75 turbo565 | JPEG q75 stb |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| GUI | 135 ms | 132 ms | 246 ms | 242 ms | 4380 ms | 3525 ms | 9025 ms | 8080 ms | 16270 ms | 8665 ms | 7830 ms | 15450 ms |
| K01 | 580 ms | 502 ms | 1068 ms | 920 ms | 12560 ms | 19395 ms | 15935 ms | 11840 ms | 20670 ms | 13650 ms | 10530 ms | 17845 ms |
| K03 | 466 ms | 410 ms | 873 ms | 748 ms | 9790 ms | 14215 ms | 13270 ms | 10095 ms | 17155 ms | 11340 ms | 9085 ms | 15625 ms |
| K15 | 549 ms | 464 ms | 1052 ms | 873 ms | 10100 ms | 15495 ms | 14395 ms | 10780 ms | 18215 ms | 12325 ms | 9665 ms | 16320 ms |
| K23 | 585 ms | 480 ms | 1175 ms | 933 ms | 9640 ms | 13280 ms | 14245 ms | 10625 ms | 17605 ms | 12340 ms | 9530 ms | 15705 ms |
| SPRITE | 79.8 ms | 76.5 ms | 123 ms | 118 ms | 1822 ms | 1988 ms | - | - | - | - | - | - |

### Encoding time

Encoding the pixels decoded from NAME.PNG (RGB565). JPEG encodes them as 8-bit RGB.

| Image | Q16 asm | Q16 asmT | Q16 C | Q16 CT | PNG libpng | JPEG q90 turbo | JPEG q75 turbo |
|---|---|---|---|---|---|---|---|
| GUI | 429 ms | 406 ms | 722 ms | 672 ms | 26510 ms | 17380 ms | 17190 ms |
| K01 | 1675 ms | 1342 ms | 3790 ms | 3405 ms | 160890 ms | 18970 ms | 17975 ms |
| K03 | 1205 ms | 1005 ms | 2805 ms | 2500 ms | 135490 ms | 17685 ms | 17135 ms |
| K15 | 1598 ms | 1315 ms | 3440 ms | 3020 ms | 148635 ms | 17970 ms | 17265 ms |
| K23 | 1662 ms | 1405 ms | 3435 ms | 3010 ms | 145720 ms | 17745 ms | 17125 ms |
| SPRITE | 246 ms | 233 ms | 387 ms | 361 ms | 14465 ms | - | - |

### Summary

* The asm Q16 decoder is **16-26 times faster than the fastest PNG decoder**
  for the same pixels (20-27 times with the static table), and **16-58 times
  faster than the fastest JPEG decoding** (libjpeg-turbo with fast settings
  directly to RGB565, which is also what a Falcon viewer would use). A
  640x480 photo takes about half a second as Q16, against 10-13 seconds as
  PNG or 9-12 seconds as JPEG.
* The asm decoder is 1.5-2.0 times faster than q16_lib.c compiled with GCC.
* Encoding with the asm encoder is **59-112 times faster than libpng** and
  **10-40 times faster than libjpeg-turbo**. A 640x480 photo takes 1.2-1.7
  seconds as Q16 (1.0-1.4 with the static table), against 2.2-2.7 minutes as
  PNG and about 18 seconds as JPEG. The asm encoder is 1.6-2.5 times faster
  than q16_lib.c and produces identical files.
* Q16 files are about the same size as PNG files with the same RGB565 pixels
  for photos (-9% to +17%), but larger for the GUI screen (+32%) and the
  sprite sheet (+84%), where PNG's deflate finds long repeated patterns.
  JPEG files of photos are 3-9 times smaller than Q16, at the cost of
  being lossy.

### Static table or hash formula

Literal and delta pixels are stored in the 64-entry palette at the index
`(p + (p >> 3) + (p >> 4) + (p >> 10)) & 63`. The default functions calculate
it, the T functions look it up in a 64 KB table that `q_genTbl()` (asm) or
`q16_setupStaticTable()` (C) fills in:

| | Calculated (default) | Static table |
|---|---|---|
| asm decoder | `q_decPix()`, m68k/q16dec.s | `q_decPxT()`, m68k/q16dect.s |
| asm encoder | `q_encPix()`, m68k/q16enc.s | `q_encPxT()`, m68k/q16enct.s |
| C decoder | `q16_decompressPixels()` | `q16_decompressPixelsT()` |
| C encoder | `q16_compressPixels()` | `q16_compressPixelsT()` |

In asm the formula is eight instructions instead of one table read. Setting
up the table takes **107.25 ms** in asm and **148.75 ms** in C (average of
20 calls), as long as decoding a whole 640x480 GUI screen. All variants give
identical results.

#### Decoding

The decoders only need the index for literal and delta pixels; index and
repeat opcodes don't. Decode time per picture on the emulated Falcon, without
setting up the table (the photo and GUI crops are 32x32 to 256x256 pixels cut
from K01 and GUI):

| Picture | Pixels | Hashed | `q_decPxT` | `q_decPix` | Per hashed pixel | `..._decompressPixelsT` | `..._decompressPixels` | Per hashed pixel |
|---|---|---|---|---|---|---|---|---|
| GUI | 307200 | 1.2% | 131.56 ms | 134.66 ms (+2.4%) | 0.84 µs | 241.66 ms | 246.11 ms (+1.8%) | 1.21 µs |
| SPRITE | 76800 | 5.6% | 76.48 ms | 79.80 ms (+4.3%) | 0.77 µs | 117.50 ms | 122.94 ms (+4.6%) | 1.26 µs |
| K03 | 307200 | 22.9% | 410.00 ms | 466.00 ms (+13.7%) | 0.80 µs | 748.33 ms | 873.33 ms (+16.7%) | 1.78 µs |
| K01 | 307200 | 33.6% | 502.50 ms | 580.00 ms (+15.4%) | 0.75 µs | 920.00 ms | 1067.50 ms (+16.0%) | 1.43 µs |
| K15 | 307200 | 35.8% | 464.00 ms | 548.75 ms (+18.3%) | 0.77 µs | 873.33 ms | 1052.50 ms (+20.5%) | 1.63 µs |
| K23 | 307200 | 43.3% | 480.00 ms | 585.00 ms (+21.9%) | 0.79 µs | 933.33 ms | 1175.00 ms (+25.9%) | 1.82 µs |
| Photo 32x32 | 1024 | 40.0% | 2.54 ms | 2.89 ms (+13.8%) | 0.85 µs | 3.44 ms | 4.00 ms (+16.3%) | 1.37 µs |
| Photo 64x64 | 4096 | 38.1% | 8.09 ms | 9.30 ms (+15.0%) | 0.78 µs | 13.07 ms | 15.34 ms (+17.4%) | 1.45 µs |
| Photo 128x128 | 16384 | 34.4% | 28.92 ms | 33.19 ms (+14.8%) | 0.76 µs | 50.62 ms | 58.71 ms (+16.0%) | 1.44 µs |
| Photo 256x256 | 65536 | 32.9% | 109.73 ms | 125.62 ms (+14.5%) | 0.74 µs | 198.18 ms | 228.33 ms (+15.2%) | 1.40 µs |
| GUI 32x32 | 1024 | 5.0% | 0.99 ms | 1.05 ms (+6.1%) | 1.17 µs | 1.24 ms | 1.28 ms (+3.2%) | 0.78 µs |
| GUI 64x64 | 4096 | 4.2% | 3.35 ms | 3.53 ms (+5.4%) | 1.05 µs | 4.60 ms | 4.76 ms (+3.5%) | 0.93 µs |
| GUI 128x128 | 16384 | 3.7% | 12.04 ms | 12.57 ms (+4.4%) | 0.87 µs | 19.32 ms | 19.90 ms (+3.0%) | 0.96 µs |
| GUI 256x256 | 65536 | 2.7% | 35.17 ms | 36.54 ms (+3.9%) | 0.77 µs | 62.27 ms | 63.90 ms (+2.6%) | 0.92 µs |

"Hashed" is the share of pixels that are literals or deltas. The formula
costs about **0.77 µs (12 cycles) per hashed pixel in asm** and about
**1.5 µs in C** (1.4-1.8 µs for the photos; the GUI pictures have so few
hashed pixels that their difference is close to the timer resolution), the
same for pictures of all sizes. So, with h hashed pixels:

    q_decPxT + table setup:   107.25 ms + t
    q_decPix:                 t + 0.77 µs x h

**Break-even at about 140 000 hashed pixels in asm** (107.25 ms / 0.77 µs)
and about 100 000 in C (148.75 ms / 1.5 µs). In pixels that is the number
of hashed pixels divided by the hashed share:

* Photos (23-43% hashed): 320 000 - 600 000 pixels in asm, about 410 000 for
  a typical photo (34% hashed), which is about 640x640. The 640x480 photos
  decode 2-52 ms faster with `q_decPix()` than with table setup +
  `q_decPxT()`; K23, with the most hashed pixels, is close to even. In C the
  break-even is lower, about 300 000 pixels for a typical photo.
* Graphics, GUIs, sprites (1-6% hashed): 2.5 - 12 million pixels in asm, far
  more than fits in a Falcon's memory, so the default functions are always
  faster.

#### Encoding

The encoders need the index for every pixel that isn't a repeat, and for
the pixel after each literal. Encode time per picture:

| Picture | `q_encPxT` | `q_encPix` | Per pixel | `..._compressPixelsT` | `..._compressPixels` | Per pixel |
|---|---|---|---|---|---|---|
| GUI | 406 ms | 429 ms (+5.7%) | 0.08 µs | 672 ms | 722 ms (+7.4%) | 0.16 µs |
| SPRITE | 233 ms | 246 ms (+5.5%) | 0.17 µs | 361 ms | 387 ms (+7.2%) | 0.34 µs |
| K03 | 1005 ms | 1205 ms (+19.9%) | 0.65 µs | 2500 ms | 2805 ms (+12.2%) | 0.99 µs |
| K01 | 1342 ms | 1675 ms (+24.8%) | 1.08 µs | 3405 ms | 3790 ms (+11.3%) | 1.25 µs |
| K15 | 1315 ms | 1598 ms (+21.5%) | 0.92 µs | 3020 ms | 3440 ms (+13.9%) | 1.37 µs |
| K23 | 1405 ms | 1662 ms (+18.3%) | 0.84 µs | 3010 ms | 3435 ms (+14.1%) | 1.38 µs |

For photos the formula costs 0.65-1.08 µs per pixel in asm and 1.0-1.4 µs
in C, so the table pays off from about 100 000 - 165 000 pixels (asm) or
110 000 - 150 000 pixels (C), even when it's set up for just one picture: a
640x480 photo encodes 8-13% faster with table setup + `q_encPxT()` than with
`q_encPix()`. For graphics, GUIs and sprites (0.08-0.34 µs per pixel) the
break-even is 0.4 - 1.4 million pixels, so the default functions are faster.

#### Which to use

The default functions need no memory and no setup, and are the better choice
when one picture is decoded at a time, like in Shower and the viewer
plugins. The table pays off when it is set up once and used for many
pictures: then the T functions win as soon as the pictures together have
more than about 140 000 hashed pixels (decoding) or a photo of about 100 000
pixels has been encoded, and after that they are 2-26% faster per picture
when decoding and 5-25% when encoding. A program that saves 640x480 photos
gains a little from the table even for a single picture.

## PC results

`pcbench.c` times encoding and decoding on a PC, using the same images. Q16,
QOI and PNG encode exactly the same RGB565 pixels (expanded to 8 bits per
channel for QOI and PNG); JPEG encodes the full color original.

| Format | Codec |
|---|---|
| Q16 | q16_lib.c |
| QOI | Own implementation of the [QOI specification](https://qoiformat.org/qoi-specification.pdf), in pcbench.c |
| PNG | libpng 1.6.43 + zlib 1.3 (default compression level 6), and stb_image_write / stb_image 2.30 |
| JPEG | libjpeg-turbo 2.1.5 (with SIMD), q90 and q75, 4:2:0, and stb_image 2.30 for decoding |

Built with GCC 13 `-O2`, run single-threaded on a 2.1 GHz Intel Xeon (cloud
VM). Each operation is repeated for at least 0.5 seconds, data is in memory.
The size table adds the Pillow-optimized PNG (the one used on the Falcon) and
lossless WebP of the RGB565 image (Pillow, default settings).

    gcc -O2 -o pcbench pcbench.c ../q16_lib.c -lpng -ljpeg -lm
    ./pcbench images K01 K03 K15 K23 GUI SPRITE > pcbench.csv
    ./pc_table.py pcbench.csv images

The Q16 times below were measured with the static table functions
(`q16_compressPixelsT()`, `q16_decompressPixelsT()`). On the PC the default
functions without the table decode at the same speed (within the
measurement noise) and encode 0-15% slower; best of three runs:

| Image | Encode T | Encode default | Decode T | Decode default |
|---|---|---|---|---|
| K01 | 2.71 ms | 2.96 ms | 1.90 ms | 1.89 ms |
| K03 | 2.33 ms | 2.40 ms | 1.87 ms | 1.69 ms |
| K15 | 2.72 ms | 2.69 ms | 1.90 ms | 1.81 ms |
| K23 | 2.59 ms | 2.96 ms | 1.78 ms | 1.96 ms |
| GUI | 0.38 ms | 0.44 ms | 0.23 ms | 0.24 ms |
| SPRITE | 0.31 ms | 0.36 ms | 0.20 ms | 0.18 ms |

These runs were made at a different time than the tables below, on a
busier VM, so they are only comparable with each other. `pcbench` times
both and prints them as codec `q16_lib` and `q16_lib T`.

### Encoding time

| Image | Q16 q16_lib | QOI qoi | PNG libpng | PNG stb | JPEG q90 libjpeg-turbo | JPEG q75 libjpeg-turbo |
|---|---|---|---|---|---|---|
| K01 | 2.27 ms | 3.95 ms | 112.7 ms | 63.6 ms | 1.19 ms | 0.98 ms |
| K03 | 2.09 ms | 3.31 ms | 85.3 ms | 59.0 ms | 0.93 ms | 0.80 ms |
| K15 | 2.20 ms | 3.67 ms | 98.9 ms | 64.6 ms | 1.01 ms | 0.89 ms |
| K23 | 2.12 ms | 4.05 ms | 92.4 ms | 63.1 ms | 0.98 ms | 0.86 ms |
| GUI | 0.28 ms | 0.78 ms | 8.45 ms | 16.7 ms | 0.78 ms | 0.75 ms |
| SPRITE | 0.22 ms | 0.40 ms | 6.39 ms | 6.59 ms | - | - |

### Decoding time

| Image | Q16 q16_lib | QOI qoi | PNG libpng | PNG stb_image | JPEG q90 libjpeg-turbo | JPEG q90 stb_image | JPEG q75 libjpeg-turbo | JPEG q75 stb_image |
|---|---|---|---|---|---|---|---|---|
| K01 | 1.75 ms | 2.42 ms | 7.78 ms | 6.46 ms | 1.59 ms | 2.76 ms | 1.19 ms | 2.03 ms |
| K03 | 1.54 ms | 2.13 ms | 5.50 ms | 5.24 ms | 1.21 ms | 1.92 ms | 0.90 ms | 1.61 ms |
| K15 | 1.62 ms | 2.22 ms | 6.00 ms | 5.17 ms | 1.30 ms | 2.25 ms | 0.96 ms | 1.75 ms |
| K23 | 1.66 ms | 2.30 ms | 5.60 ms | 4.65 ms | 1.28 ms | 2.10 ms | 0.95 ms | 1.69 ms |
| GUI | 0.17 ms | 0.35 ms | 1.71 ms | 1.02 ms | 0.96 ms | 1.92 ms | 0.81 ms | 1.54 ms |
| SPRITE | 0.12 ms | 0.21 ms | 0.82 ms | 0.65 ms | - | - | - | - |

### File size

| Image | Q16 | QOI | PNG libpng | PNG optimized | PNG stb | WebP lossless | PNG full color | JPEG q90 | JPEG q75 |
|---|---|---|---|---|---|---|---|---|---|
| K01 | 358 KB | 543 KB | 385 KB | 379 KB | 546 KB | 217 KB | 610 KB | 120 KB | 72 KB |
| K03 | 249 KB | 365 KB | 284 KB | 274 KB | 415 KB | 145 KB | 409 KB | 58 KB | 33 KB |
| K15 | 307 KB | 486 KB | 312 KB | 302 KB | 456 KB | 179 KB | 482 KB | 73 KB | 41 KB |
| K23 | 299 KB | 494 KB | 266 KB | 255 KB | 401 KB | 160 KB | 444 KB | 63 KB | 34 KB |
| GUI | 40 KB | 53 KB | 31 KB | 30 KB | 41 KB | 7 KB | 41 KB | 55 KB | 39 KB |
| SPRITE | 55 KB | 93 KB | 31 KB | 30 KB | 41 KB | 23 KB | 37 KB | - | - |

### Summary

* Q16 encodes 30-50 times faster than libpng and 1.6-2.8 times faster than
  QOI. libjpeg-turbo, with its SIMD code, encodes photos 2-2.6 times as fast
  as Q16, but Q16 is faster for the GUI screen.
* Q16 decodes 3-10 times faster than PNG and 1.4-2 times faster than QOI.
  libjpeg-turbo decodes photos 1.1-1.7 times as fast as Q16 thanks to SIMD
  (on the Falcon, without SIMD, it's 20-60 times slower), while Q16 is about
  5 times faster for the GUI screen.
* For RGB565 pictures Q16 files are 25-40% smaller than QOI, which is made for
  8-bit channels, and about as large as PNG for photos. Lossless WebP is
  40-80% smaller than Q16 but much slower to encode and decode.

## Caveats

* Hatari's 68030 timing is approximate, and it's uncertain how accurately it
  models ST-RAM wait states and memory bandwidth taken by the video hardware,
  which depends on the screen mode. Absolute numbers may differ from a real
  Falcon, but all decoders run under the same conditions.
* The decoders don't produce the same output. Q16 and turbo565 deliver RGB565
  that can be copied straight to a Falcon true color screen, while the others
  deliver 8-bit RGB(A) that still needs converting, which isn't included in
  the times.
* JPEG is lossy and much smaller. Q16 and the benchmarked PNG files hold
  exactly the same pixels.
* The Falcon's DSP can be used for JPEG decoding (as done by some Falcon
  image viewers). That isn't covered here.

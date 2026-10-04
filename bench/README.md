# Benchmarks

Compares decoding and encoding speed of Q16, PNG and JPEG on an Atari Falcon
(68030 at 16 MHz), emulated by Hatari, and encoding and decoding speed and file sizes
of Q16, QOI, PNG and JPEG on a PC (see [PC results](#pc-results)).

| Format | Decoder | Output |
|---|---|---|
| Q16 | `asm`: m68k/q16dec.s | RGB565 (+ 8-bit alpha) |
| Q16 | `C`: q16_lib.c | RGB565 (+ 8-bit alpha) |
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

For each PNG file, the decoded pixels are also encoded with the asm
(m68k/q16enc.s) and C Q16 encoders, libpng (default compression, level 6)
and libjpeg-turbo (quality 90 and 75, not for the sprite sheet).

Each file is decoded from memory, repeatedly for at least two seconds. Timing
uses the 200 Hz system timer. The program also verifies that the asm and C Q16
decoders give identical results, as do libpng and stb_image and the asm
and C Q16 encoders, and that each
Q16 file decodes to exactly the same pixels as the corresponding RGB565 PNG.

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

| Image | Q16 asm | Q16 C | PNG libpng | PNG stb | JPEG q90 turbo | JPEG q90 turbo565 | JPEG q90 stb | JPEG q75 turbo | JPEG q75 turbo565 | JPEG q75 stb |
|---|---|---|---|---|---|---|---|---|---|---|
| GUI | 132 ms | 242 ms | 4390 ms | 3440 ms | 9025 ms | 8080 ms | 16210 ms | 8665 ms | 7830 ms | 15395 ms |
| K01 | 502 ms | 920 ms | 12565 ms | 18330 ms | 15930 ms | 11840 ms | 20555 ms | 13650 ms | 10530 ms | 17775 ms |
| K03 | 410 ms | 748 ms | 9805 ms | 13630 ms | 13265 ms | 10095 ms | 17085 ms | 11340 ms | 9085 ms | 15590 ms |
| K15 | 464 ms | 873 ms | 10110 ms | 14820 ms | 14395 ms | 10775 ms | 18130 ms | 12320 ms | 9665 ms | 16285 ms |
| K23 | 480 ms | 933 ms | 9640 ms | 12855 ms | 14245 ms | 10625 ms | 17540 ms | 12340 ms | 9530 ms | 15655 ms |
| SPRITE | 76.5 ms | 118 ms | 1825 ms | 1915 ms | - | - | - | - | - | - |

### Encoding time

Encoding the pixels decoded from NAME.PNG (RGB565). JPEG encodes them as 8-bit RGB.

| Image | Q16 asm | Q16 C | PNG libpng | JPEG q90 turbo | JPEG q75 turbo |
|---|---|---|---|---|---|
| GUI | 405 ms | 707 ms | 26430 ms | 17370 ms | 17185 ms |
| K01 | 1342 ms | 3775 ms | 160745 ms | 18965 ms | 17975 ms |
| K03 | 1005 ms | 2730 ms | 135330 ms | 17675 ms | 17130 ms |
| K15 | 1315 ms | 3275 ms | 148390 ms | 17965 ms | 17255 ms |
| K23 | 1405 ms | 3225 ms | 145585 ms | 17740 ms | 17120 ms |
| SPRITE | 233 ms | 375 ms | 14410 ms | - | - |

### Summary

* The asm Q16 decoder is **20-26 times faster than the fastest PNG decoder**
  for the same pixels, and **19-60 times faster than the fastest JPEG
  decoding** (libjpeg-turbo with fast settings directly to RGB565, which is
  also what a Falcon viewer would use). A 640x480 photo takes about half a
  second as Q16, against 10-13 seconds as PNG or 9-12 seconds as JPEG.
* The asm decoder is 1.5-1.9 times faster than q16_lib.c compiled with GCC.
* Encoding with the asm encoder is **60-135 times faster than libpng** and
  **12-42 times faster than libjpeg-turbo**. A 640x480 photo takes 1.0-1.4
  seconds as Q16, against 2.2-2.7 minutes as PNG and about 18 seconds as
  JPEG. The asm encoder is 1.6-2.8 times faster than q16_lib.c and produces
  identical files.
* Q16 files are about the same size as PNG files with the same RGB565 pixels
  for photos (-9% to +17%), but larger for the GUI screen (+32%) and the
  sprite sheet (+84%), where PNG's deflate finds long repeated patterns.
  JPEG files of photos are 3-9 times smaller than Q16, at the cost of
  being lossy.

### Static table or hash formula

`q_decPix()` looks up the palette index of each new pixel in a 64 KB table
that `q16_setupStaticTable()` fills in. `q_decPixF()` in `m68k/q16decf.s`
calculates it with the formula instead, `(p + (p >> 3) + (p >> 4) + (p >> 10))
& 63`: eight instructions instead of one table read. Only literal and delta
pixels need the index; index and repeat opcodes don't.

Measured on the emulated Falcon (decode time per picture, without setting up
the table; the photo and GUI crops are 32x32 to 256x256 pixels cut from K01
and GUI):

| Picture | Pixels | Hashed | `q_decPix` | `q_decPixF` | Difference | Per hashed pixel |
|---|---|---|---|---|---|---|
| GUI | 307200 | 1.2% | 131.56 ms | 134.66 ms | +2.4% | 0.81 µs |
| SPRITE | 76800 | 5.6% | 76.48 ms | 79.80 ms | +4.3% | 0.77 µs |
| K03 | 307200 | 22.9% | 410.00 ms | 465.00 ms | +13.4% | 0.78 µs |
| K01 | 307200 | 33.6% | 501.25 ms | 578.75 ms | +15.5% | 0.75 µs |
| K15 | 307200 | 35.8% | 464.00 ms | 548.75 ms | +18.3% | 0.77 µs |
| K23 | 307200 | 43.3% | 480.00 ms | 585.00 ms | +21.9% | 0.79 µs |
| Photo 32x32 | 1024 | 40.0% | 2.53 ms | 2.89 ms | +14.2% | 0.88 µs |
| Photo 64x64 | 4096 | 38.1% | 8.06 ms | 9.30 ms | +15.4% | 0.80 µs |
| Photo 128x128 | 16384 | 34.4% | 28.85 ms | 33.11 ms | +14.8% | 0.76 µs |
| Photo 256x256 | 65536 | 32.9% | 109.47 ms | 125.62 ms | +14.8% | 0.75 µs |
| GUI 32x32 | 1024 | 5.0% | 0.99 ms | 1.05 ms | +6.1% | 1.18 µs |
| GUI 64x64 | 4096 | 4.2% | 3.35 ms | 3.53 ms | +5.4% | 1.04 µs |
| GUI 128x128 | 16384 | 3.7% | 12.04 ms | 12.57 ms | +4.4% | 0.87 µs |
| GUI 256x256 | 65536 | 2.7% | 35.17 ms | 36.54 ms | +3.9% | 0.78 µs |

"Hashed" is the share of pixels that are literals or deltas. Setting up the
table takes **107.25 ms** (average of 20 calls), as long as decoding a whole
640x480 GUI screen.

The formula costs about **0.77 µs (12 cycles) per hashed pixel**, the same
for all pictures (the smallest pictures measure a little higher, as fixed
costs per call weigh more there). So, with h hashed pixels:

    q_decPix  + table setup:  107.25 ms + t
    q_decPixF:                t + 0.77 µs x h

**Break-even at about 140 000 hashed pixels** (107.25 ms / 0.77 µs). In
pixels that is 140 000 / hashed share:

* Photos (23-43% hashed): 320 000 - 600 000 pixels, about 410 000 for a
  typical photo (34% hashed), which is about 640x640. The 640x480 photos
  decode 2-52 ms faster with `q_decPixF()` than with table setup +
  `q_decPix()`; K23, with the most hashed pixels, is close to even.
* Graphics, GUIs, sprites (1-5% hashed): 2.5 - 10 million pixels, far more
  than fits in a Falcon's memory, so `q_decPixF()` is always faster.

The table only pays off when it is set up once and used for many pictures:
then `q_decPix()` wins as soon as the pictures together have more than about
140 000 hashed pixels, for example after one large photo or a few small
ones, and after that it is 2-22% faster per picture. For a viewer that shows
one picture per run, like Shower, `q_decPixF()` is the better choice, and it
also saves the 64 KB.

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

# Falcon decoding benchmark

Compares decoding speed of Q16, PNG and JPEG on an Atari Falcon (68030 at
16 MHz), emulated by Hatari.

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

Each file is decoded from memory, repeatedly for at least two seconds. Timing
uses the 200 Hz system timer. The program also verifies that the asm and C Q16
decoders give identical results, as do libpng and stb_image, and that each
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
| GUI | 132 ms | 242 ms | 4385 ms | 3410 ms | 9030 ms | 8170 ms | 16175 ms | 8670 ms | 7845 ms | 15290 ms |
| K01 | 502 ms | 920 ms | 12735 ms | 18110 ms | 15980 ms | 11800 ms | 20490 ms | 13650 ms | 10410 ms | 17810 ms |
| K03 | 411 ms | 748 ms | 9885 ms | 13425 ms | 13290 ms | 10115 ms | 17080 ms | 11360 ms | 9035 ms | 15510 ms |
| K15 | 465 ms | 873 ms | 10200 ms | 14630 ms | 14430 ms | 10805 ms | 18105 ms | 12330 ms | 9575 ms | 16105 ms |
| K23 | 481 ms | 933 ms | 9740 ms | 12645 ms | 14205 ms | 10550 ms | 17545 ms | 12330 ms | 9450 ms | 15680 ms |
| SPRITE | 76.5 ms | 118 ms | 1830 ms | 1878 ms | - | - | - | - | - | - |

### Summary

* The asm Q16 decoder is **20-26 times faster than the fastest PNG decoder**
  for the same pixels, and **19-60 times faster than the fastest JPEG
  decoding** (libjpeg-turbo with fast settings directly to RGB565, which is
  also what a Falcon viewer would use). A 640x480 photo takes about half a
  second as Q16, against 10-13 seconds as PNG or 9-12 seconds as JPEG.
* The asm decoder is 1.5-1.9 times faster than q16_lib.c compiled with GCC.
* Q16 files are about the same size as PNG files with the same RGB565 pixels
  for photos (-9% to +17%), but larger for the GUI screen (+32%) and the
  sprite sheet (+84%), where PNG's deflate finds long repeated patterns.
  JPEG files of photos are 3-9 times smaller than Q16, at the cost of
  being lossy.

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

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

RESULTS

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

# q16
QOI inspired compression for 16-bit RGB565 images.

* `q16_lib.c`/`q16_lib.h` - C library for compression and decompression, with the file format description.
* `gen_q16`, `q16to*`, `q16info`, `q16bench` - command line tools.
* `m68k/` - fast decoder in 68020/68030 assembly for the Atari Falcon and TT.
* `bench/` - decoding speed benchmark against PNG and JPEG on an (emulated) Atari Falcon, with results.

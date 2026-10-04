# q16
QOI inspired compression for 16-bit RGB565 images.

* `q16_lib.c`/`q16_lib.h` - C library for compression and decompression, with the file format description.
* `gen_q16`, `q16to*`, `q16info`, `q16bench` - command line tools.
* `m68k/` - fast decoder and encoder in 68020/68030 assembly for the Atari Falcon and TT.
* `bench/` - speed and size benchmarks against PNG, JPEG and QOI on an (emulated) Atari Falcon and on PC, with results.
* `shower/` - Shower 1.2, the Falcon picture viewer, disassembled from version 1.1 and extended with Q16 support.
* `plugins/` - Q16 plugins for the zView and GEM-View viewers and the Smurf graphics editor.

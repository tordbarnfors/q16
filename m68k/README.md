# Q16 decoder and encoder for 68020/68030

`q16dec.s` is a Q16 decoder in Devpac syntax for the Atari Falcon, TT and
other 68020+ machines. `q16dec.h` is its C interface. It decodes images that
have been loaded into memory in their entirety, pixels and alpha separately.

`q16enc.s` is the matching encoder, with `q16enc.h` as C interface. It
compresses complete images, pixels with `q_encPix()` and alpha with
`q_encAlp()`, and writes the header with `q16_writeHeader()`. The output is
byte-identical to q16_lib.c. It uses `q16_setupStaticTable()` from
`q16dec.s`, so link with both.

* C-callable from GCC, VBCC, Lattice C, Pure C and AHCC. All arguments are
  passed on the stack (the header declares the functions `cdecl` for Pure C
  and AHCC) and all parameters are pointers or 32-bit values, so the int size
  of the compiler doesn't matter.
* Preserves all registers except d0-d1/a0-a1. Pointers are returned in both
  d0 and a0, as compilers differ in which register they expect.
* Reentrant, uses no DATA or BSS. The decoder needs a 64 KB table, set up by
  `q16_setupStaticTable()`, that can be shared between calls.
* Never reads beyond the end of the input nor writes beyond the end of the
  output, even for corrupt files. Returns -1 if the data doesn't decode into
  exactly the expected number of pixels.

Differences from the C library: the decompress functions decode a complete
stream in one call, take the number of pixels instead of an instance table
and return 0 or -1 instead of a struct. The compress functions also handle a
complete stream in one call and need no instance table.

On an emulated Falcon the asm decoder is 1.5-1.9 times and the asm encoder
1.6-1.7 times faster than q16_lib.c compiled with GCC, see
[../bench](../bench/README.md).

## Assembling

Devpac 3: assemble `q16dec.s` and `q16enc.s` to linkable object files. Both
files can also be INCLUDEd into a program.

vasm (`vasmm68k_mot`):

    vasmm68k_mot -devpac -Faout -o q16dec.o q16dec.s   # GCC/MiNT (a.out)
    vasmm68k_mot -devpac -Felf -o q16dec.o q16dec.s    # GCC/MiNT (ELF)

and the same for `q16enc.s`.

Every function is exported both with and without a leading underscore.

The decode and encode functions are named `q_decPix`, `q_decAlp`, `q_encPix`
and `q_encAlp` to fit within the 8 character symbol names of the DRI object
format.

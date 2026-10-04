# Q16 decoder for 68020/68030

`q16dec.s` is a Q16 decoder in Devpac syntax for the Atari Falcon, TT and
other 68020+ machines. `q16dec.h` is its C interface. It decodes images that
have been loaded into memory in their entirety, pixels and alpha separately.

* C-callable from GCC, VBCC, Lattice C, Pure C and AHCC. All arguments are
  passed on the stack (the header declares the functions `cdecl` for Pure C
  and AHCC) and all parameters are pointers or 32-bit values, so the int size
  of the compiler doesn't matter.
* Preserves all registers except d0-d1/a0-a1.
* Reentrant, uses no DATA or BSS. The decoder needs a 64 KB table, set up by
  `q16_setupStaticTable()`, that can be shared between calls.
* Never reads beyond the end of the input nor writes beyond the end of the
  output, even for corrupt files. Returns -1 if the data doesn't decode into
  exactly the expected number of pixels.

Differences from the C library: the decompress functions decode a complete
stream in one call, take the number of pixels instead of an instance table
and return 0 or -1 instead of a struct.

## Assembling

Devpac 3: assemble `q16dec.s` to a linkable object file.

vasm (`vasmm68k_mot`):

    vasmm68k_mot -devpac -Faout -o q16dec.o q16dec.s   # GCC/MiNT (a.out)
    vasmm68k_mot -devpac -Felf -o q16dec.o q16dec.s    # GCC/MiNT (ELF)

Every function is exported both with and without a leading underscore.

The decode functions are named `q_decPix` and `q_decAlp` to fit within the
8 character symbol names of the DRI object format.

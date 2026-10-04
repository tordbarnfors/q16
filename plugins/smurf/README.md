# Q16 modules for Smurf

[Smurf](https://github.com/th-otto/smurf) is a graphics editor for Atari
computers with import and export modules. `Q16.SIM` is an import module and
`Q16.SXM` an export module for Q16 pictures.

* Import decodes to 16-bit RGB565, Smurf's native True Color format, so no
  conversion is needed. Smurf has no alpha channel, so pictures with alpha
  are blended against white.
* Export saves 16-bit pictures as Q16 (without alpha). Smurf converts
  pictures of other depths to 16 bit before calling the module.
* Use q16_lib.c and are built for the 68000.

The modules are built with gcc and are for gcc builds of Smurf, such as the
one built from the GitHub sources: Smurf checks that a module was built with
the same compiler as itself (`MOD_INFO.compiler_id`), since Pure C and gcc
use different calling conventions and int sizes. The original Smurf 1.06
binaries are built with Pure C and won't load these modules.

## Installing

Copy `Q16.SIM` into `modules\import` and `Q16.SXM` into `modules\export` in
Smurf's folder.

## Building

    ./build.sh [smurf source directory] [vasm executable]

needs m68k-atari-mint-gcc
([Vincent Rivière's PPA](https://launchpad.net/~vriviere/+archive/ubuntu/ppa))
and [vasm](http://sun.hasenbraten.de/vasm/) for the startup code
(`impstart.s`, `expstart.s`). Six headers from Smurf are downloaded from
GitHub unless a Smurf source tree is given.

## Testing

`test/smurftst.c` loads the modules the same way Smurf does (`Pexec()` mode 3,
module header at the start of the TEXT segment, `start_module()`) and calls
them with a minimal `GARGAMEL` structure: the import module with a Q16 file,
the export module with the imported pixels and Smurf's message sequence
(`MEXTEND`, `MCOLSYS`, `MSTART`, `MEXEC`, `MTERM`). It reads the file names
from `SMURFTST.CFG`.

Tested in Hatari (Falcon, EmuTOS): imported pixels match a reference decoder
for pictures with and without alpha, and a picture without alpha exports to a
byte-identical file.

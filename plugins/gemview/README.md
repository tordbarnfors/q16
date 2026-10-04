# Q16 load module for GEM-View

GEM-View 3 by Dieter Fiebelkorn is an image viewer for Atari computers with loadable
modules. `Q16.GVL` is a load module that lets it open Q16 pictures.

* Written in Devpac assembly and uses `../../m68k/q16dec.s`, so it needs a
  68020 or better (Falcon, TT).
* Delivers a True Color image, which GEM-View displays in any screen mode.
  Pictures with alpha are blended against white.
* Supports GEM-View's automatic format identification (the "Auto" flag).

GEM-View calls load modules with the Pure C register calling convention, and
the module follows the layout of the `LOAD_Structure` and `Image` structures
in GEM-View's module developer kit (`MODULS.H` and `IMAGE.H`).

## Installing

Copy `Q16.GVL` into the `GVWLOAD` folder in GEM-View's folder.

## Building

    ./build.sh path/to/vasmm68k_mot

## Testing

Tested with GEM-View 3.18 in Hatari (Falcon, EmuTOS, VGA 16 colors), opening
Q16 pictures with and without alpha given on the command line.

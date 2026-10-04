# Q16 modules for GEM-View

GEM-View 3 by Dieter Fiebelkorn is an image viewer for Atari computers with loadable
modules. `Q16.GVL` is a load module that lets it open Q16 pictures, and
`Q16.GVS` a save module that lets it save pictures as Q16.

* Written in Devpac assembly and use `../../m68k/q16dec.s` and
  `../../m68k/q16enc.s`, so they need a 68020 or better (Falcon, TT).
* The load module delivers a True Color image, which GEM-View displays in any
  screen mode. Pictures with alpha are blended against white. It supports
  GEM-View's automatic format identification (the "Auto" flag).
* The save module saves True Color, palette (chunky and bitplanes) and
  monochrome pictures as RGB565 Q16 without alpha (GEM-View pictures have
  none). Palette pictures are saved with their colours applied. GEM-View
  hands palette pictures to save modules as they are, even when saving as
  True Color, which is why the module takes all types.

GEM-View calls the modules with the Pure C register calling convention, and
they follow the layout of the `LOAD_Structure`, `SAVE_Structure` and `Image`
structures in GEM-View's module developer kit (`MODULS.H` and `IMAGE.H`). The
save module writes the file through GEM-View's `output` functions and reports
in GEM-View's log window.

## Installing

Copy `Q16.GVL` into the `GVWLOAD` folder and `Q16.GVS` into the `GVWSAVE`
folder in GEM-View's folder. Q16 then appears as "Q16 RGB565" among the save
formats, for example in "Saving Dflt..".

## Building

    ./build.sh path/to/vasmm68k_mot

## Testing

Tested with GEM-View 3.18 in Hatari (Falcon, EmuTOS, VGA 16 colors):

* Load module: opening Q16 pictures with and without alpha given on the
  command line.
* Save module: with "Q16 RGB565" as `DfltSavingTC` in GEMVIEW.INF,
  `GEMVIEW.APP -noshow -saveall truecolor <picture>` saved a 24-bit Targa
  picture, a 256-colour GIF (chunky palette), a 16-colour Degas PI1
  (bitplanes) and a monochrome Degas PI3; all decode to the expected pixels.
  A Q16 picture loaded with `Q16.GVL` and saved with `Q16.GVS` gave a
  byte-identical file.

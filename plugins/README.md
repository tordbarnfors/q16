# Plugins for Atari image viewers and editors

| Host | Type | Plugin | Import | Export | CPU | Tested |
|---|---|---|---|---|---|---|
| [zView](zview/) | Viewer | `Q16.LDG` (LDG codec) | yes | yes | 68000+ | Codec test program in Hatari |
| [GEM-View 3](gemview/) | Viewer | `Q16.GVL` (load module) | yes | - | 68020+ | GEM-View 3.18 in Hatari |
| [Smurf](smurf/) | Editor | `Q16.SIM`, `Q16.SXM` | yes | yes | 68000+ | Module test program in Hatari |

Shower, the viewer in [../shower](../shower/), has Q16 support built in.

All plugins blend alpha against white (Shower against black), since none of
the hosts handles an alpha channel. The zView codec uses the background color
zView asks for, which is white by default.

## Hosts that were looked at but not done

* **Papillon** has import modules, but they can only deliver pictures with up
  to 256 colors as bitplanes.
* **ImgView**, **Positive Image**: plugin interfaces without public
  documentation.
* **PhotoLine** has only filter plugins. **Apex Media**, **Imagine**,
  **Chagall** and **MGIF** have no plugin interfaces. Aniplayer's plugins are
  for audio and video.

## Possible improvements

* A Pure C build of the Smurf modules, for the original Smurf 1.06 binaries.
  That needs 16-bit int (gcc `-mshort`) and thunks for Pure C's register
  calling convention, and a Pure C Smurf to test with.
* A GEM-View save module (`.GVS`).
* Smaller zView codec: it's linked with MiNTLib's startup code, which makes
  it about 120 KB.

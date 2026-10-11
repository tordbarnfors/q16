# Q16 file format specification

Format version 1.

Q16 is a lossless format for 16-bit RGB565 images with an optional 8-bit
alpha channel. The pixel compression is inspired by
[QOI](https://qoiformat.org/). File extension: `.q16`.

## File layout

```
header        20 bytes
pixel stream  pixelBytes bytes
alpha stream  alphaBytes bytes (only if alphaBytes > 0)
```

All multi-byte values are little endian. The streams have no end marker;
their lengths are given in the header.

## Header

```c
struct q16_header {        // offset
    char     magic[4];     //  0  "Q565" (0x51 0x35 0x36 0x35)
    uint8_t  version;      //  4  1
    uint8_t  flags;        //  5  bit 0: 0 = sRGB, 1 = linear RGB. Other bits 0.
    uint16_t width;        //  6  in pixels
    uint16_t height;       //  8  in pixels
    uint16_t reserved;     // 10  0
    uint32_t pixelBytes;   // 12  size of the pixel stream
    uint32_t alphaBytes;   // 16  size of the alpha stream, 0 if no alpha
};
```

Decoders must reject files with a version they don't support.

## Pixels

An image has width × height pixels, stored row by row from top to bottom,
each row from left to right, with no padding.

A pixel is a 16-bit RGB565 value: red in bits 15-11, green in bits 10-5,
blue in bits 4-0.

Alpha values are 8 bits, linear, not premultiplied: 0 is fully transparent,
255 fully opaque.

## Pixel stream

The decoder keeps two pieces of state, both all zero at the start:

* `prev`: the previous pixel, 0x0000.
* `palette[64]`: 64 recently seen pixels, all 0x0000.

Each new pixel produced by a LITERAL or DELTA op is stored in the palette at

```
index = (p + (p >> 3) + (p >> 4) + (p >> 10)) & 63
```

with p as an unsigned 16-bit value. Only the low 6 bits of the sum are used,
so it can be computed in 16-bit arithmetic. INDEX and REPEAT don't change
the palette.

Every op starts with one byte, identified by its top bits:

| Op | Byte 0 | Bytes after | Pixels |
|---|---|---|---|
| LITERAL | `000nnnnn` (0x00-0x1F) | 2 × (n + 1) | n + 1 |
| REPEAT | `001nnnnn` (0x20-0x3F) | 0 | n + 1 |
| INDEX | `01iiiiii` (0x40-0x7F) | 0 | 1 |
| DELTA | `1rrgggbb` (0x80-0xFF) | 0 | 1 |

**LITERAL**: n + 1 pixels (1-32) follow, each as a 16-bit little endian
value. Each pixel is output, stored in the palette and becomes `prev`.

**REPEAT**: outputs `prev` n + 1 times (1-32).

**INDEX**: outputs `palette[i]`, which becomes `prev`.

**DELTA**: outputs `prev` with each channel changed by a small difference.
The fields are stored with a bias:

| Channel | Bits | Difference |
|---|---|---|
| red | 6-5 | rr - 2, so -2 to +1 |
| green | 4-2 | ggg - 4, so -4 to +3 |
| blue | 1-0 | bb - 2, so -2 to +1 |

```
p = (prev + dr × 2048 + dg × 32 + db) mod 65536
```

The new pixel is output, stored in the palette and becomes `prev`. Encoders
only write DELTA when no channel wraps around, so computing the channels
separately gives the same result.

Byte 0xD2 (DELTA with all differences 0) is reserved and never written by
encoders, which use REPEAT instead. Decoders may treat it as an error or as a
zero DELTA, and may place it after the stream in memory as a sentinel.

The pixel stream must decode into exactly width × height pixels and end
with the last byte of an op.

### Encoding (informative)

Any valid op sequence is allowed. The reference encoder, for each pixel:

1. if it equals `prev`: REPEAT, counting up to 32 equal pixels;
2. else if `palette[index]` holds it: INDEX;
3. else if each channel differs from `prev` within the DELTA ranges: DELTA;
4. else: LITERAL, adding following pixels (up to 32 in total) until one
   could be stored by 1-3.

An image may also be compressed in several parts, carrying `prev` and the
palette over between them; ops never span two parts. This doesn't affect
decoding.

The pixel stream is at most n × 2 + n / 32 + 1 bytes for n pixels (integer
division), plus 1 byte for each additional part.

## Alpha stream

Present only if alphaBytes > 0. It holds width × height alpha values, in
the same order as the pixels. The decoder keeps `prevAlpha`, 0 at the
start. Each code c is one signed byte:

| Code c | Meaning |
|---|---|
| 0 to 127 | c + 1 alpha values (1-128) follow verbatim. The last becomes `prevAlpha`. |
| -1 to -128 | Repeat `prevAlpha` -c times (1-128). |

The stream must decode into exactly width × height values. Encoders start
the stream, and each part if it is compressed in several, with a verbatim
code. The alpha stream is at most n + n / 128 + 1 bytes for n values, plus
1 byte for each additional part.

## Reference decoder

```c
uint16_t prev = 0, palette[64] = {0};
const uint8_t *p = pixelStream, *end = pixelStream + pixelBytes;

while (p < end) {
    uint8_t b = *p++;
    if (b < 0x20) {                                   // LITERAL
        for (int i = 0; i <= b; i++, p += 2) {
            prev = p[0] | (p[1] << 8);
            *out++ = prev;
            palette[HASH(prev)] = prev;
        }
    } else if (b < 0x40) {                            // REPEAT
        for (int i = 0; i <= (b & 31); i++)
            *out++ = prev;
    } else if (b < 0x80) {                            // INDEX
        prev = palette[b & 63];
        *out++ = prev;
    } else {                                          // DELTA
        int dr = ((b >> 5) & 3) - 2, dg = ((b >> 2) & 7) - 4, db = (b & 3) - 2;
        prev = (uint16_t)(prev + dr * 2048 + dg * 32 + db);
        *out++ = prev;
        palette[HASH(prev)] = prev;
    }
}
```

`HASH(p)` is the palette index formula above. A real decoder must also
check that no op reads past the end of the stream or writes more than
width × height pixels.

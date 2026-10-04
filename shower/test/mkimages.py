#!/usr/bin/env python3
"""Writes the test pictures for regress.py into a directory.

Usage: mkimages.py <directory> [gen_q16]

All pictures show the same pattern, 321 x 203 pixels: an odd width that
isn't a multiple of 16 and a size smaller than the screen. The pattern is
asymmetric, so flipped or skewed pictures are easy to spot.

Targa: Tbdco.TGA with b = bits per pixel (16, 24, 32), c = R (raw) or
C (RLE), o = B (bottom-left origin, the default) or T (top-left origin).
The RLE pictures are compressed line by line, as Targa 2.0 requires.

BMP: B8.BMP (256 colours, 321 x 203), B8W.BMP (320 x 203) and B8TD.BMP
(stored top-down).

Larger than the screen (700 x 530): TBIG.TGA (24 bits, RLE, bottom-left
origin) and GBIG.GIF (interlaced).

GIF: G87.GIF (GIF87a), GINT.GIF (interlaced), G89.GIF (GIF89a with a
graphic control and a comment extension before the image).

Q16: Q16.Q16, written with gen_q16 (built from the repository) if given.

For each picture an expected RGB rendering is written as NAME.PNG
(16-bit pictures are reduced to 15 or 16 bits per pixel).
"""
import os, struct, subprocess, sys
from PIL import Image, ImageDraw

W, H = 321, 203
d = sys.argv[1]
os.makedirs(d, exist_ok=True)


def pattern(W=W, H=H):
    im = Image.new("RGB", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            px[x, y] = (x * 255 // (W - 1), y * 255 // (H - 1), 255 - (x + y) * 255 // (W + H - 2))
    dr = ImageDraw.Draw(im)
    dr.rectangle((0, 0, W - 1, H - 1), outline=(255, 255, 255))
    dr.rectangle((4, 4, 40, 30), fill=(255, 0, 0))             # Red block top left
    dr.rectangle((W - 30, H - 20, W - 5, H - 5), fill=(0, 0, 0))  # Black block bottom right
    dr.line((0, 0, W - 1, H - 1), fill=(255, 255, 0))
    dr.text((60, 10), "TOP", fill=(255, 255, 255))
    for x in range(0, W, 2):                                    # Flat runs for RLE
        dr.point((x, 100), fill=(0, 255, 0))
    dr.rectangle((100, 120, 300, 160), fill=(40, 80, 160))
    return im


def tga_pixels(im, bits):
    out = []
    raw = im.tobytes()
    for r, g, b in zip(raw[0::3], raw[1::3], raw[2::3]):
        if bits == 16:
            v = 0x8000 | (r >> 3) << 10 | (g >> 3) << 5 | (b >> 3)
            out.append(struct.pack("<H", v))
        elif bits == 24:
            out.append(bytes((b, g, r)))
        else:
            out.append(bytes((b, g, r, 255)))
    return out


def rle(pixels):
    out, i, n = bytearray(), 0, len(pixels)
    while i < n:
        j = i
        while j + 1 < n and j - i < 127 and pixels[j + 1] == pixels[i]:
            j += 1
        if j > i:
            out += bytes((0x80 | (j - i),)) + pixels[i]
            i = j + 1
        else:
            j = i
            while j + 1 < n and j - i < 127 and pixels[j + 1] != pixels[j]:
                j += 1
            if j + 1 < n and j > i:
                j -= 1                  # Leave the start of a run.
            out += bytes((j - i,)) + b"".join(pixels[i:j + 1])
            i = j + 1
    return bytes(out)


def write_tga(name, im, bits, compressed, top):
    W, H = im.size
    rows = im if top else im.transpose(Image.FLIP_TOP_BOTTOM)
    px = tga_pixels(rows, bits)
    data = b"".join(rle(px[y * W:(y + 1) * W]) for y in range(H)) if compressed else b"".join(px)
    ident = b"Q16 test"
    hdr = struct.pack("<BBBHHBHHHHBB", len(ident), 0, 10 if compressed else 2, 0, 0, 0, 0, 0, W, H, bits,
                      (0x20 if top else 0) | (8 if bits == 32 else 1 if bits == 16 else 0))
    open(os.path.join(d, name), "wb").write(hdr + ident + data)


def reduce(im, rbits, gbits, bbits):
    def f(v, n):
        v >>= 8 - n
        return (v << (8 - n)) | (v >> (2 * n - 8)) if n >= 4 else v << (8 - n)
    return Image.merge("RGB", [b.point(lambda v, n=n: f(v, n)) for b, n in zip(im.split(), (rbits, gbits, bbits))])


im = pattern()
for bits in (16, 24, 32):
    for compressed in (False, True):
        for top in (False, True):
            name = "T%d%s%s" % (bits, "C" if compressed else "R", "T" if top else "B")
            write_tga(name + ".TGA", im, bits, compressed, top)
            # The screen is RGB565, so 24/32-bit pictures lose bits too.
            reduce(im, 5, 5 if bits == 16 else 6, 5).save(os.path.join(d, name + ".PNG"))

pal = im.quantize(256, dither=Image.Dither.NONE)
exp = pal.convert("RGB")
pal.save(os.path.join(d, "G87.GIF"), interlace=False)
pal.save(os.path.join(d, "GINT.GIF"), interlace=True)
pal.save(os.path.join(d, "G89.GIF"), interlace=False, comment=b"Q16 test", duration=100, transparency=255)
# The Falcon palette has 6 bits per component.
for n in ("G87", "GINT", "G89"):
    reduce(exp, 6, 6, 6).save(os.path.join(d, n + ".PNG"))
pal.save(os.path.join(d, "B8.BMP"))
pal.crop((0, 0, 320, H)).save(os.path.join(d, "B8W.BMP"))
reduce(exp, 6, 6, 6).save(os.path.join(d, "B8.PNG"))
reduce(exp.crop((0, 0, 320, H)), 6, 6, 6).save(os.path.join(d, "B8W.PNG"))
# Top-down BMP: rows in file order reversed and a negative height.
bmp = bytearray(open(os.path.join(d, "B8.BMP"), "rb").read())
off, stride = struct.unpack_from("<I", bmp, 10)[0], (W + 3) & ~3
rows = [bmp[off + y * stride:off + (y + 1) * stride] for y in range(H)]
bmp[off:] = b"".join(reversed(rows))
struct.pack_into("<i", bmp, 22, -H)
open(os.path.join(d, "B8TD.BMP"), "wb").write(bmp)
reduce(exp, 6, 6, 6).save(os.path.join(d, "B8TD.PNG"))

big = pattern(700, 530)
write_tga("TBIG.TGA", big, 24, True, False)
reduce(big, 5, 6, 5).save(os.path.join(d, "TBIG.PNG"))
bigpal = big.quantize(256, dither=Image.Dither.NONE)
bigpal.save(os.path.join(d, "GBIG.GIF"), interlace=True)
reduce(bigpal.convert("RGB"), 6, 6, 6).save(os.path.join(d, "GBIG.PNG"))

for n in ("G87", "GINT", "G89"):
    data = open(os.path.join(d, n + ".GIF"), "rb").read()
    print(n, data[:6].decode(), "interlaced" if n == "GINT" else "", "extension" if b"\x21\xf9" in data[:1000] else "")

# Q16
if len(sys.argv) > 2:
    im.save(os.path.join(d, "Q16_SRC.PNG"))
    subprocess.run([sys.argv[2], os.path.join(d, "Q16_SRC.PNG")], check=True, stdout=subprocess.DEVNULL)
    os.replace(os.path.join(d, "Q16_SRC.q16"), os.path.join(d, "Q16.Q16"))
    os.remove(os.path.join(d, "Q16_SRC.PNG"))
    reduce(im, 5, 6, 5).save(os.path.join(d, "Q16.PNG"))

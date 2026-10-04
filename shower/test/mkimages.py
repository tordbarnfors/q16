#!/usr/bin/env python3
"""Writes the test pictures for regress.py into a directory.

Usage: mkimages.py <directory> [gen_q16]

All pictures show the same pattern, mostly at 321 x 203 pixels: an odd
width that isn't a multiple of 16 and a size smaller than the screen.
Formats with a fixed size use that size. The pattern is asymmetric, so
flipped or skewed pictures are easy to spot.

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

Degas: D1.PI1 (low resolution), D1C.PC1 (compressed), D2C.PC2 (compressed
medium resolution, shown with doubled lines), D4.PI4 (320 x 240, 256
colours) and D5.PI5 (640 x 480, 256 colours). The ST palettes use 3 bits
per component.

GEM IMG (321 x 203): I4.IMG (4 planes without a palette, shown with the
system palette, which is EmuTOS's desktop palette in Hatari), I4X.IMG
(XIMG palette) and I1.IMG (monochrome). The data uses all IMG item types:
solid runs, bit strings, pattern runs and vertical repeats.

POV raw: RAW.RAW (321 x 203, 24 bits per pixel). IndyPaint: TRU.TRU
(321 x 203).

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


# ---- Bitplane formats

# Falcon palette registers 0-15 in Hatari's Falcon with EmuTOS 1.3 on VGA
# (the desktop palette), read with Supexec at the time Shower starts.
EMUTOS_PALETTE = [(252, 252, 252), (252, 0, 0), (0, 252, 0), (252, 252, 0), (0, 0, 252), (252, 0, 252),
                  (0, 252, 252), (184, 184, 184), (136, 136, 136), (168, 0, 0), (0, 168, 0), (168, 168, 0),
                  (0, 0, 168), (168, 0, 168), (0, 168, 168), (0, 0, 0)]

# 3 bits per component ST colours, as (r, g, b) 0-7.
ST16 = [(7, 7, 7), (7, 0, 0), (0, 7, 0), (7, 7, 0), (0, 0, 7), (7, 0, 7), (0, 7, 7), (5, 5, 5),
        (3, 3, 3), (7, 3, 0), (0, 4, 2), (4, 2, 6), (2, 2, 5), (6, 4, 4), (1, 5, 6), (0, 0, 0)]
ST4 = [(7, 7, 7), (7, 0, 0), (0, 3, 7), (0, 0, 0)]


def quantize(im, colours):
    """Index image using the nearest of the given (r, g, b) 0-255 colours."""
    cache = {}
    def nearest(rgb):
        if rgb not in cache:
            cache[rgb] = min(range(len(colours)), key=lambda i: sum((a - b) ** 2 for a, b in zip(rgb, colours[i])))
        return cache[rgb]
    raw = im.tobytes()
    idx = Image.new("P", im.size)
    idx.putdata([nearest(tuple(raw[i:i + 3])) for i in range(0, len(raw), 3)])
    return idx


def expected(idx, colours):
    out = Image.new("RGB", idx.size)
    out.putdata([colours[i] for i in idx.getdata()])
    return out


def plane_lines(idx, planes):
    """For each line, the bytes of each plane (MSB = leftmost pixel)."""
    w, h = idx.size
    px = list(idx.getdata())
    nb = (w + 7) // 8
    lines = []
    for y in range(h):
        row = px[y * w:(y + 1) * w] + [0] * (nb * 8 - w)
        lines.append([bytes(sum(((row[x * 8 + b] >> p) & 1) << (7 - b) for b in range(8)) for x in range(nb))
                      for p in range(planes)])
    return lines


def interleaved(idx, planes):
    """ST/Falcon screen format: for each 16 pixels, one word per plane."""
    out = bytearray()
    for line in plane_lines(idx, planes):
        for x in range(0, len(line[0]), 2):
            for p in range(planes):
                out += line[p][x:x + 2]
    return bytes(out)


def packbits(data):
    out, i, n = bytearray(), 0, len(data)
    while i < n:
        j = i
        while j + 1 < n and j - i < 127 and data[j + 1] == data[i]:
            j += 1
        if j > i:
            out += bytes((257 - (j - i + 1),)) + data[i:i + 1]       # -(count - 1)
            i = j + 1
        else:
            j = i
            while j + 1 < n and j - i < 127 and data[j + 1] != data[j]:
                j += 1
            if j + 1 < n and j > i:
                j -= 1
            out += bytes((j - i,)) + data[i:j + 1]
            i = j + 1
    return bytes(out)


def ste_words(colours):
    return b"".join(struct.pack(">H", r << 8 | g << 4 | b) for r, g, b in colours) + b"\0\0" * (16 - len(colours))


def st_rgb(colours):
    return [(r << 5, g << 5, b << 5) for r, g, b in colours]       # As Shower's st_palette


def falcon_palette(colours):
    return b"".join(bytes((r & 0xFC, g & 0xFC, 0, b & 0xFC)) for r, g, b in colours) + b"\0" * (1024 - 4 * len(colours))


def save(name, data, exp):
    open(os.path.join(d, name), "wb").write(data)
    exp.save(os.path.join(d, os.path.splitext(name)[0] + ".PNG"))


# Degas low resolution, plain and compressed.
low = quantize(pattern(320, 200), st_rgb(ST16))
lowexp = expected(low, st_rgb(ST16))
save("D1.PI1", struct.pack(">H", 0) + ste_words(ST16) + interleaved(low, 4), lowexp)
pc1 = bytearray()
for line in plane_lines(low, 4):
    for plane in line:
        pc1 += packbits(plane)
save("D1C.PC1", struct.pack(">H", 0x8000) + ste_words(ST16) + bytes(pc1) + b"\0" * 32, lowexp)

# Degas compressed medium resolution, 640 x 200 shown as 640 x 400.
med = quantize(pattern(640, 200), st_rgb(ST4))
pc2 = bytearray()
for line in plane_lines(med, 2):
    for plane in line:
        pc2 += packbits(plane)
# 2-plane screens use the STE palette registers, which have 4 bits per
# component: 3-bit value v is shown as 2v / 15.
save("D2C.PC2", struct.pack(">H", 0x8001) + ste_words(ST4) + bytes(pc2) + b"\0" * 32,
     expected(med, [tuple(round(2 * c * 255 / 15) for c in rgb) for rgb in ST4]).resize((640, 400), Image.NEAREST))

# Extended Degas in 256 colours with a Falcon palette.
for name, size in (("D4.PI4", (320, 240)), ("D5.PI5", (640, 480))):
    q = pattern(*size).quantize(256, dither=Image.Dither.NONE)
    cols = [tuple(q.getpalette()[3 * i:3 * i + 3]) for i in range(256)]
    save(name, falcon_palette(cols) + interleaved(q, 8), reduce(expected(q, cols), 6, 6, 6))


# GEM IMG. Rows 150-169 repeat row 149 (vertical repeats) and a
# checkerboard of colours 0 and 15 makes pattern runs.

def img_items(data):
    out, i, n = bytearray(), 0, len(data)
    while i < n:
        b = data[i]
        if b in (0, 0xFF):
            j = i
            while j < n and data[j] == b and j - i < 127:
                j += 1
            out.append((0x80 if b else 0) | (j - i))                 # Solid run
            i = j
            continue
        pat = data[i:i + 2]
        if len(pat) == 2 and data[i:i + 6] == pat * 3:
            k = 0
            while data[i + 2 * k:i + 2 * k + 2] == pat and k < 255:
                k += 1
            out += bytes((0, k)) + pat                               # Pattern run
            i += 2 * k
            continue
        j = i
        while j < n and j - i < 255 and data[j] not in (0, 0xFF) and data[j:j + 6] != data[j:j + 2] * 3:
            j += 1
        j = max(j, i + 1)
        out += bytes((0x80, j - i)) + data[i:j]                      # Bit string
        i = j
    return bytes(out)


def write_img(name, idx, planes, palette=None):
    w, h = idx.size
    lines = plane_lines(idx, planes)
    body, y = bytearray(), 0
    while y < h:
        count = 1
        while y + count < h and lines[y + count] == lines[y] and count < 255:
            count += 1
        if count > 1:
            body += bytes((0, 0, 0xFF, count))                       # Vertical repeat
        for plane in lines[y]:
            body += img_items(plane)
        y += count
    ximg = b""
    if palette:
        ximg = b"XIMG" + struct.pack(">H", 0) + b"".join(
            struct.pack(">HHH", *[round(c * 1000 / 255) for c in rgb]) for rgb in palette)
    hdr = struct.pack(">8H", 1, 8 + len(ximg) // 2, planes, 2, 85, 85, w, h)
    open(os.path.join(d, name), "wb").write(hdr + ximg + bytes(body))


def img_source(colours):
    src = pattern()
    for y in range(150, 170):
        src.paste(src.crop((0, 149, W, 150)), (0, y))
    idx = quantize(src, colours)
    px = idx.load()
    for y in range(175, 195):
        for x in range(150, 280):
            px[x, y] = 0 if (x + y) & 1 else len(colours) - 1
    return idx


idx = img_source(EMUTOS_PALETTE)
write_img("I4.IMG", idx, 4)
expected(idx, EMUTOS_PALETTE).save(os.path.join(d, "I4.PNG"))

q = pattern().quantize(16, dither=Image.Dither.NONE)
xcols = [tuple(q.getpalette()[3 * i:3 * i + 3]) for i in range(16)]
idx = img_source(xcols)
write_img("I4X.IMG", idx, 4, xcols)
# Shower scales XIMG values (0-1000) with (v + 8) * 100 / 396.
shown = [tuple(((round(c * 1000 / 255) + 8) * 100 // 396) & 0xFC for c in rgb) for rgb in xcols]
expected(idx, shown).save(os.path.join(d, "I4X.PNG"))

mono = img_source([(255, 255, 255), (0, 0, 0)])
write_img("I1.IMG", mono, 1)
expected(mono, [(255, 255, 255), (0, 0, 0)]).save(os.path.join(d, "I1.PNG"))

# POV raw: width and height as text, then 24-bit pixels.
save("RAW.RAW", b"%d %d\n" % (W, H) + im.tobytes(), reduce(im, 5, 6, 5))

# IndyPaint: "Indy", width and height, then big endian RGB565 pixels from
# offset 256.
rgb565 = b"".join(struct.pack(">H", (r >> 3) << 11 | (g >> 2) << 5 | b >> 3) for r, g, b in
                  zip(*[iter(im.tobytes())] * 3))
save("TRU.TRU", (b"Indy" + struct.pack(">HH", W, H)).ljust(256, b"\0") + rgb565, reduce(im, 5, 6, 5))

# Q16
if len(sys.argv) > 2:
    im.save(os.path.join(d, "Q16_SRC.PNG"))
    subprocess.run([sys.argv[2], os.path.join(d, "Q16_SRC.PNG")], check=True, stdout=subprocess.DEVNULL)
    os.replace(os.path.join(d, "Q16_SRC.q16"), os.path.join(d, "Q16.Q16"))
    os.remove(os.path.join(d, "Q16_SRC.PNG"))
    reduce(im, 5, 6, 5).save(os.path.join(d, "Q16.PNG"))

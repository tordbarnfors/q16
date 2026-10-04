#!/usr/bin/env python3
"""Makes Markdown tables from the CSV output of pcbench.

Usage: pc_table.py <pcbench.csv> <image directory>

The image directory is the one written by make_images.py. It's used for the
sizes of files not written by pcbench: NAME.PNG (Pillow, optimize=True),
NAME_F.PNG (full color) and lossless WebP of the RGB565 image, which is
encoded here with Pillow.
"""

import csv, io, os, sys
from collections import OrderedDict
from PIL import Image

rows = list(csv.DictReader(open(sys.argv[1])))
d = sys.argv[2]

data = OrderedDict()
for r in rows:
    data.setdefault(r["name"], {})[(r["format"], r["codec"])] = r


def get(name, fmt, codec, field):
    r = data[name].get((fmt, codec))
    return float(r[field]) if r and r[field] else None


def ms(v):
    if v is None:
        return "-"
    return "%.2f ms" % v if v < 10 else "%.1f ms" % v


def kb(n):
    return "%.0f KB" % (n / 1024) if n else "-"


def webp565(name):
    img = Image.open(os.path.join(d, name + "_F.PNG"))
    bands = list(img.split())
    for i, mask in enumerate((0xF8, 0xFC, 0xF8)):
        bands[i] = bands[i].point(lambda v, m=mask: v & m)
    buf = io.BytesIO()
    Image.merge(img.mode, bands).save(buf, "WEBP", lossless=True)
    return len(buf.getvalue())


def fsize(name):
    p = os.path.join(d, name)
    return os.path.getsize(p) if os.path.exists(p) else None


enc_cols = [("Q16", "q16_lib"), ("QOI", "qoi"), ("PNG", "libpng"), ("PNG", "stb"),
            ("JPEG q90", "libjpeg-turbo"), ("JPEG q75", "libjpeg-turbo")]
dec_cols = [("Q16", "q16_lib"), ("QOI", "qoi"), ("PNG", "libpng"), ("PNG", "stb_image"),
            ("JPEG q90", "libjpeg-turbo"), ("JPEG q90", "stb_image"),
            ("JPEG q75", "libjpeg-turbo"), ("JPEG q75", "stb_image")]

print("### Encoding time\n")
print("| Image | " + " | ".join("%s %s" % (f, c) for f, c in enc_cols) + " |")
print("|---" * (len(enc_cols) + 1) + "|")
for n in data:
    print("| %s | %s |" % (n, " | ".join(ms(get(n, f, c, "encode_ms")) for f, c in enc_cols)))

print("\n### Decoding time\n")
print("| Image | " + " | ".join("%s %s" % (f, c) for f, c in dec_cols) + " |")
print("|---" * (len(dec_cols) + 1) + "|")
for n in data:
    print("| %s | %s |" % (n, " | ".join(ms(get(n, f, c, "decode_ms")) for f, c in dec_cols)))

print("\n### File size\n")
print("| Image | Q16 | QOI | PNG libpng | PNG optimized | PNG stb | WebP lossless | PNG full color | JPEG q90 | JPEG q75 |")
print("|---|---|---|---|---|---|---|---|---|---|")
for n in data:
    b = lambda f, c: get(n, f, c, "bytes")
    print("| %s | %s |" % (n, " | ".join(kb(x) for x in [
        b("Q16", "q16_lib"), b("QOI", "qoi"), b("PNG", "libpng"), fsize(n + ".PNG"), b("PNG", "stb"),
        webp565(n), fsize(n + "_F.PNG"), b("JPEG q90", "libjpeg-turbo"), b("JPEG q75", "libjpeg-turbo")])))

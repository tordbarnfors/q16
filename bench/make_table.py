#!/usr/bin/env python3
"""Makes Markdown tables from BENCH.TXT written by FALCBNCH.TOS.

Usage: make_table.py <image directory>

Reads BENCH.TXT and the image files in the directory (for file sizes,
including NAME_F.PNG which isn't benchmarked).
"""

import os, re, sys
from collections import OrderedDict

d = sys.argv[1]
times = {}                      # (file, decoder) -> ms
for line in open(os.path.join(d, "BENCH.TXT")):
    m = re.match(r"(\S+)\s+(\d+)\s+(\S+)\s+([\d.]+) ms", line)
    if m:
        times[(m.group(1), m.group(3))] = float(m.group(4))

def size(name):
    p = os.path.join(d, name)
    return os.path.getsize(p) if os.path.exists(p) else None

def kb(n):
    return "%.0f KB" % (n / 1024) if n else "-"

def ms(f, dec):
    t = times.get((f, dec))
    if t is None:
        return "-"
    return ("%.0f ms" % t) if t >= 100 else ("%.1f ms" % t)

names = OrderedDict()
for f, _ in times:
    names.setdefault(f.split(".")[0].split("_")[0], None)

print("### File sizes\n")
print("| Image | Q16 | PNG (RGB565) | PNG (24/32-bit) | JPEG q90 | JPEG q75 |")
print("|---|---|---|---|---|---|")
for n in names:
    print("| %s | %s | %s | %s | %s | %s |" % (n, kb(size(n + ".Q16")), kb(size(n + ".PNG")), kb(size(n + "_F.PNG")),
                                             kb(size(n + "_90.JPG")), kb(size(n + "_75.JPG"))))

print("\n### Decoding time\n")
print("| Image | Q16 asm | Q16 C | PNG libpng | PNG stb | JPEG q90 turbo | JPEG q90 turbo565 | JPEG q90 stb | JPEG q75 turbo | JPEG q75 turbo565 | JPEG q75 stb |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for n in names:
    print("| %s | %s |" % (n, " | ".join([ms(n + ".Q16", "asm"), ms(n + ".Q16", "C"),
                                          ms(n + ".PNG", "libpng"), ms(n + ".PNG", "stb"),
                                          ms(n + "_90.JPG", "turbo"), ms(n + "_90.JPG", "turbo565"), ms(n + "_90.JPG", "stb"),
                                          ms(n + "_75.JPG", "turbo"), ms(n + "_75.JPG", "turbo565"), ms(n + "_75.JPG", "stb")])))

#!/usr/bin/env python3
"""Generates the benchmark image set in Q16, PNG and JPEG formats.

Usage: make_images.py <gen_q16> <photo_dir> <out_dir>

photo_dir should contain kodim01.png, kodim03.png, kodim15.png and kodim23.png
from the Kodak test set (https://r0k.us/graphics/kodak/). They are center
cropped to 640x480. Two graphics images are generated: a GUI style screen and
a sprite sheet with alpha.

For every image the following files are written (8.3 names for TOS):

  NAME.Q16    Q16 (RGB565, lossless, with alpha if the image has alpha)
  NAME.PNG    PNG of the image reduced to RGB565, i.e. the same pixels as Q16
  NAME_90.JPG JPEG quality 90 (images without alpha only)
  NAME_75.JPG JPEG quality 75 (images without alpha only)

plus NAME_F.PNG, a PNG of the original full color 24/32-bit image, for size
comparison.
"""

import os, subprocess, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

gen_q16, photo_dir, out_dir = sys.argv[1:4]
os.makedirs(out_dir, exist_ok=True)


def to565(img):
    """Reduces to RGB565 precision, keeping 8-bit alpha."""
    bands = list(img.split())
    bands[0] = bands[0].point(lambda v: v & 0xF8)
    bands[1] = bands[1].point(lambda v: v & 0xFC)
    bands[2] = bands[2].point(lambda v: v & 0xF8)
    return Image.merge(img.mode, bands)


def photo(name):
    img = Image.open(os.path.join(photo_dir, name + ".png")).convert("RGB")
    w, h = img.size
    return img.crop(((w - 640) // 2, (h - 480) // 2, (w + 640) // 2, (h + 480) // 2))


def font(size):
    return ImageFont.load_default(size)


def gui():
    """GUI style screen: desktop gradient, windows, text, buttons, icons."""
    img = Image.new("RGB", (640, 480))
    d = ImageDraw.Draw(img)
    for y in range(480):
        d.line([(0, y), (639, y)], fill=(30 + y // 8, 60 + y // 6, 120 + y // 5))
    for i, (x, y, w, h, title) in enumerate([(30, 40, 360, 260, "Q16 Viewer"), (250, 180, 360, 270, "Settings")]):
        d.rectangle([x + 6, y + 6, x + w + 6, y + h + 6], fill=(10, 20, 40))
        d.rectangle([x, y, x + w, y + h], fill=(236, 236, 232), outline=(80, 80, 80))
        for t in range(24):
            c = 200 - t * 3 if i == 0 else 160 - t * 2
            d.line([(x + 1, y + 1 + t), (x + w - 1, y + 1 + t)], fill=(c // 3, c // 2, c))
        d.text((x + 10, y + 4), title, fill=(255, 255, 255), font=font(15))
        for row in range(6):
            d.text((x + 16, y + 40 + row * 22), "Option %d: compression level %d%%" % (row + 1, 40 + row * 9), fill=(20, 20, 20), font=font(13))
        for b, label in enumerate(["OK", "Cancel", "Apply"]):
            bx = x + w - 90 * (3 - b) - 10
            d.rounded_rectangle([bx, y + h - 40, bx + 80, y + h - 12], radius=6, fill=(210, 210, 215), outline=(120, 120, 130))
            d.text((bx + 40, y + h - 26), label, fill=(0, 0, 0), font=font(14), anchor="mm")
    for i in range(6):
        cx, cy = 590, 40 + i * 70
        d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=((i * 40) % 256, 180, 255 - i * 30), outline=(255, 255, 255), width=2)
        d.text((cx, cy + 32), "Item %d" % i, fill=(255, 255, 255), font=font(12), anchor="mm")
    return img


def sprites():
    """Sprite sheet with antialiased shapes and soft shadows on transparent background."""
    size = (320, 240)
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    ds = ImageDraw.Draw(shadow)
    shapes = Image.new("RGBA", (size[0] * 4, size[1] * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(shapes)
    for i in range(12):
        x, y = 15 + (i % 4) * 78, 15 + (i // 4) * 75
        ds.ellipse([x + 6, y + 8, x + 62, y + 64], fill=(0, 0, 0, 140))
        col = (255 - i * 18, 60 + i * 15, 120 + (i * 37) % 130, 255)
        X, Y = x * 4, y * 4
        if i % 3 == 0:
            d.ellipse([X, Y, X + 224, Y + 224], fill=col)
            d.ellipse([X + 40, Y + 30, X + 120, Y + 100], fill=(255, 255, 255, 160))
        elif i % 3 == 1:
            d.rounded_rectangle([X, Y, X + 224, Y + 224], radius=50, fill=col)
            d.rectangle([X + 40, Y + 90, X + 184, Y + 134], fill=(255, 255, 255, 200))
        else:
            d.polygon([(X + 112, Y), (X + 224, Y + 224), (X, Y + 224)], fill=col)
    shapes = shapes.resize(size, Image.LANCZOS)
    shadow = shadow.filter(ImageFilter.GaussianBlur(4))
    return Image.alpha_composite(shadow, shapes)


images = [("K01", photo("kodim01")), ("K03", photo("kodim03")), ("K15", photo("kodim15")),
          ("K23", photo("kodim23")), ("GUI", gui()), ("SPRITES", sprites())]

for name, img in images:
    base = os.path.join(out_dir, name)
    img.save(base + "_F.PNG", optimize=True)
    to565(img).save(base + ".PNG", optimize=True)
    if img.mode == "RGB":
        img.save(base + "_90.JPG", quality=90)
        img.save(base + "_75.JPG", quality=75)
    subprocess.run([gen_q16, base + "_F.PNG"], check=True, stdout=subprocess.DEVNULL)
    os.replace(base + "_F.q16", base + ".Q16")
    print(name, img.size, img.mode)

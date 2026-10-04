#!/usr/bin/env python3
"""Shows the pictures made by mkimages.py with Shower in Hatari (Falcon,
VGA) and compares the screen with the expected rendering.

Usage: regress.py <SHOWER.TTP> <picture directory> <output directory> [names...]

Runs several Hatari instances in parallel. For each picture the screenshot
is saved as <output directory>/NAME.png and the result printed: the share
of pixels in the picture area that differ from NAME.PNG by more than a
small tolerance, and whether the screen around the picture is clean.

Needs LAUNCH.TOS next to this script (see showtest.py) and the EmuTOS image
in the EMUTOS environment variable.
"""
import glob, os, shutil, socket, subprocess, sys, tempfile, time
from concurrent.futures import ThreadPoolExecutor
from PIL import Image

ttp, picdir, outdir = sys.argv[1:4]
names = sys.argv[4:] or sorted(os.path.splitext(os.path.basename(f))[0]
                               for f in glob.glob(os.path.join(picdir, "*.PNG")))
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(outdir, exist_ok=True)
DELAY, TOLERANCE, JOBS = 20, 12, 4


def picture_file(name):
    for f in os.listdir(picdir):
        base, ext = os.path.splitext(f)
        if base == name and ext.upper() != ".PNG":
            return f


def run(name):
    pic = picture_file(name)
    tmp = tempfile.mkdtemp()
    hd = os.path.join(tmp, "hd")
    os.makedirs(hd)
    shutil.copy(ttp, os.path.join(hd, "SHOWER.TTP"))
    shutil.copy(os.path.join(picdir, pic), hd)
    shutil.copy(os.path.join(here, "LAUNCH.TOS"), hd)
    open(os.path.join(hd, "LAUNCH.CMD"), "w").write("C:\\SHOWER.TTP C:\\%s" % pic)
    sock = os.path.join(tmp, "ctrl.sock")
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(sock)
    srv.listen(1)
    shots = os.path.join(tmp, "shots")
    os.makedirs(shots)
    env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
    p = subprocess.Popen(["hatari", "--machine", "falcon", "--tos", os.environ["EMUTOS"], "--cpulevel", "3",
                          "--cpuclock", "16", "--cpu-exact", "yes", "--fpu", "none", "--dsp", "none",
                          "--memsize", "14", "--ttram", "0", "--monitor", "vga", "--natfeats", "yes",
                          "--fast-boot", "yes", "--sound", "off", "--harddrive", hd,
                          "--auto", "C:\\LAUNCH.TOS", "--confirm-quit", "no", "--screenshot-dir", shots,
                          "--crop", "yes", "--run-vbls", "20000", "--control-socket", sock],
                         env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    conn, _ = srv.accept()
    try:
        time.sleep(DELAY)
        conn.sendall(b"hatari-shortcut screenshot\n")
        time.sleep(2)
        conn.sendall(b"hatari-event keypress 57\n")
    except BrokenPipeError:
        p.wait()
        shutil.rmtree(tmp)
        return name, "FAIL  Shower quit before the screenshot (picture rejected or crash)"
    try:
        p.wait(timeout=60)
    except subprocess.TimeoutExpired:
        p.kill()
    files = sorted(glob.glob(os.path.join(shots, "*")))
    if not files:
        shutil.rmtree(tmp)
        return name, "no screenshot"
    shot = os.path.join(outdir, name + ".png")
    shutil.copy(files[-1], shot)
    shutil.rmtree(tmp)
    return name, compare(shot, os.path.join(picdir, name + ".PNG"))


def compare(shot, expected):
    s = Image.open(shot).convert("RGB")
    # In ST compatible modes (2 planes) Hatari's screenshot includes a left
    # border, 86 pixels on VGA; TOS's own screens in that mode are placed
    # the same way.
    if s.size[0] > 640:
        s = s.crop((s.size[0] - 640, 0, s.size[0], 480))
    e = Image.open(expected).convert("RGB")
    # True color pictures (Targa, Q16, POV raw) are shown on a 320 x 240
    # screen, which Hatari doubles in both directions; pictures with bitplanes
    # on a 640 x 480 one.
    base = os.path.basename(expected)
    scale = 2 if base.startswith(("T", "Q16", "RAW")) else 1
    sw, sh = s.size[0] // scale, s.size[1] // scale
    w, h = e.size
    rw = (w + 15) & ~15
    x0 = max(0, (sw - rw) >> 1 >> 4 << 4)
    y0 = max(0, (sh - h) >> 1)
    sp, ep = s.load(), e.load()
    px = lambda x, y: sp[x * scale, y * scale]
    vis = [(x, y) for y in range(min(h, sh - y0)) for x in range(min(w, sw - x0))]
    bad = sum(1 for x, y in vis if max(abs(a - b) for a, b in zip(px(x0 + x, y0 + y), ep[x, y])) > TOLERANCE)
    # Outside the picture (and its padding up to 16 pixels) the screen
    # should be a single colour.
    border = set(px(x, y) for y in range(sh) for x in range(sw)
                 if not (x0 <= x < x0 + rw and y0 <= y < y0 + h))
    clean = len(border) <= 1
    return "%s  %.1f%% of pixels differ, border %s" % ("PASS" if bad == 0 and clean else "FAIL",
                                                        100.0 * bad / len(vis), "clean" if clean else "NOT clean")


with ThreadPoolExecutor(JOBS) as ex:
    for name, result in ex.map(run, names):
        print("%-8s %s" % (name, result), flush=True)

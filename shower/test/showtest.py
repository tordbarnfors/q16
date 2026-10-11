#!/usr/bin/env python3
"""Runs a TOS program with arguments in Hatari (Falcon), takes a screenshot
after a delay, presses Space and waits for Hatari to quit.

Usage: showtest.py <hd dir> <program> <args> <screenshot.png> [delay seconds]

Example: showtest.py hd 'C:\\SHOWER.TTP' 'C:\\PICTURE.Q16' shot.png 25

<hd dir> is mounted as drive C:. LAUNCH.TOS (assembled from launch.s with
vasmm68k_mot -devpac -Ftos -o LAUNCH.TOS launch.s) must be in the same
directory as this script. Set EMUTOS to the EmuTOS image and MONITOR to
vga (default) or rgb.
"""
import os, socket, subprocess, sys, time, glob, shutil

hd, prog, args, shot = sys.argv[1:5]
delay = float(sys.argv[5]) if len(sys.argv) > 5 else 20
here = os.path.dirname(os.path.abspath(__file__))
tos = os.environ["EMUTOS"]

shutil.copy(os.path.join(here, "LAUNCH.TOS"), hd)
open(os.path.join(hd, "LAUNCH.CMD"), "w").write("%s %s" % (prog, args))
sockpath = "/tmp/hatari-ctrl.sock"
if os.path.exists(sockpath):
    os.unlink(sockpath)
srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(sockpath)
srv.listen(1)
shotdir = os.path.join(here, "shots")
shutil.rmtree(shotdir, ignore_errors=True)
os.makedirs(shotdir)
env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
p = subprocess.Popen(["hatari", "--machine", "falcon", "--tos", tos, "--cpulevel", "3", "--cpuclock", "16",
                      "--cpu-exact", "yes", "--fpu", "none", "--dsp", "none", "--memsize", "14", "--ttram", "0",
                      "--monitor", os.environ.get("MONITOR", "vga"), "--natfeats", "yes", "--fast-boot", "yes",
                      "--sound", "off", "--harddrive", hd, "--auto", "C:\\LAUNCH.TOS", "--confirm-quit", "no",
                      "--screenshot-dir", shotdir, "--crop", "yes", "--run-vbls", "20000",
                      "--control-socket", sockpath], env=env, stdout=open(os.path.join(here, "hatari.log"), "w"),
                     stderr=subprocess.STDOUT)
conn, _ = srv.accept()
time.sleep(delay)
conn.sendall(b"hatari-shortcut screenshot\n")
time.sleep(2)
conn.sendall(b"hatari-event keypress 57\n")
try:
    p.wait(timeout=60)
except subprocess.TimeoutExpired:
    p.kill()
shots = sorted(glob.glob(os.path.join(shotdir, "*")))
if shots:
    shutil.copy(shots[-1], shot)
    print("screenshot:", shot)
else:
    print("no screenshot taken")

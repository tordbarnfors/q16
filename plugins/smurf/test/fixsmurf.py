#!/usr/bin/env python3
"""Patches the gcc builds of Smurf from GitHub so they can display pictures.

Several of Smurf's .s files choose between gcc's 32-bit and 16-bit int
calling conventions with C preprocessor conditionals (#ifndef __MSHORT__),
but they are assembled without the preprocessor, so both variants end up in
the binaries, one after the other, and the second, wrong one wins. Loading
any picture then crashes Smurf (the plane conversion runs off the end of RAM,
and the dither modules call the busy box callback a second time with a
clobbered address).

This assembles both variants of every such block and, wherever the correct
one is directly followed by the wrong one in a binary, replaces the wrong
one with NOPs. Needs m68k-atari-mint-as and -objcopy.

Usage: fixsmurf.py <smurf source directory> <binaries...>
  e.g. fixsmurf.py smurf-src SMURF/smurf.prg $(find SMURF/modules -type f)

The binaries are modified in place.
"""
import re, subprocess, sys, os, tempfile
src, bins = sys.argv[1], sys.argv[2:]
MARK = bytes.fromhex('4afc1a2b3c4d')
blocks = []
for f in subprocess.check_output(['grep','-rl','__MSHORT__','--include=*.s',src]).decode().split():
    lines = open(f, errors='replace').read().splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r'#if(n?)def\s+__MSHORT__', lines[i].strip())
        if m:
            a, b = [], []; cur = a; j = i + 1
            while not lines[j].strip().startswith('#endif'):
                if lines[j].strip().startswith('#else'): cur = b
                else: cur.append(lines[j])
                j += 1
            good, wrong = (a, b) if m.group(1) == 'n' else (b, a)
            if wrong: blocks.append((os.path.relpath(f, src), i + 1, good, wrong))
            i = j
        i += 1
tmp = tempfile.mkdtemp()
def asm(lines):
    s, o, b = (os.path.join(tmp, 'b' + e) for e in ('.s', '.o', '.bin'))
    open(s, 'w').write('\t.text\n' + '\n'.join(lines) + '\n')
    subprocess.run(['m68k-atari-mint-as','-m68030','--register-prefix-optional','-o',o,s], check=True)
    subprocess.run(['m68k-atari-mint-objcopy','-O','binary','-j','.text',o,b], check=True)
    return open(b,'rb').read()
mk = ['\t.word 0x4afc,0x1a2b,0x3c4d']
pats = {}
for f, ln, good, wrong in blocks:
    code = asm(good + mk + wrong + mk)
    g, w = code.split(MARK)[:2]
    pats.setdefault((g, w), []).append('%s:%d' % (f, ln))
found = set(); total = 0
for p in bins:
    d = bytearray(open(p,'rb').read()); n = 0
    for (g, w), where in pats.items():
        i = d.find(g + w)
        while i >= 0:
            d[i+len(g):i+len(g)+len(w)] = b'\x4e\x71' * (len(w)//2); n += 1; found.add((g, w))
            i = d.find(g + w, i + 1)
    if n:
        open(p,'wb').write(d); print(os.path.basename(p), n); total += n
print('blocks', len(blocks), 'patterns', len(pats), 'patched', total)
for k, where in pats.items():
    if k not in found: print('not found in these binaries:', where[:3])

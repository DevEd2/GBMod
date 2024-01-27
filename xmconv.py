import argparse
import math
import struct
import array
import random

parser = argparse.ArgumentParser(description='Converts .xm module to GBMod')
parser.add_argument('-n', metavar='sname', help='Song name (default = none)')
parser.add_argument('-a', metavar='author', help='Author name (default = none)')
parser.add_argument('-t', metavar='timerCtrl', help='Timer control (default = 0)')
parser.add_argument('-m', metavar='timerModulo', help='Timer modulo (default = 0)')
parser.add_argument('fi', metavar='I', type=argparse.FileType('rb'), help='Input file name')
parser.add_argument('fo', metavar='O', type=argparse.FileType('wb'), help='Output file name')
nsp = parser.parse_args()

def s8(a): return int.from_bytes(a.read(1), "little", signed=True)
def u8(a): return int.from_bytes(a.read(1), "little", signed=False)
def le16(a): return int.from_bytes(a.read(2), "little", signed=False)
def le32(a): return int.from_bytes(a.read(4), "little", signed=False)

class XMRow:
    def __init__(self, a):
        self.note = 0
        self.ins = 0
        self.vol = 0
        self.cmd = 0
        self.par = 0

        info = u8(a)
        if not info & 0x80: # full row
            self.note = info & 0x7f
            info = 0xfe
        if info & 0x01:
            self.note = u8(a)
        if info & 0x02:
            self.ins = u8(a)
        if info & 0x04:
            self.vol = u8(a)
        if info & 0x08:
            self.cmd = u8(a)
        if info & 0x10:
            self.par = u8(a)

class XMSampleHeader:
    def __init__(self, a):
        self.size = le32(a)
        self.loopstart = le32(a)
        self.looplen = le32(a)
        self.volume = u8(a)
        self.finetune = u8(a)
        self.type = u8(a)
        self.pan = u8(a)
        self.c5note = s8(a)
        self.reserved = u8(a)
        self.name = fin.read(22).decode().strip()

fin = nsp.fi
fou = nsp.fo
sname = nsp.n
author = nsp.a
timerCtrl = nsp.t
timerModulo = nsp.m
if sname == None:
    sname = ""
if author == None:
    author = ""
if timerCtrl == None:
    timerCtrl = 0
else:
	timerCtrl = int(timerCtrl)
if timerModulo == None:
    timerModulo = 0
else:
	timerModulo = int(timerModulo)
if fin.read(17) != b"Extended Module: ":
    raise Exception("Invalid magic number. This is not .xm module file!")

name = fin.read(20).decode().strip()
if name == "":
    name = fin.name
print("Converting {} into GBMod data...".format(name))

fin.seek(1, 1) # EOF char
tracker = fin.read(20).decode().strip()
version = le16(fin)
if version < 0x104:
    raise Exception("Unsupported file version!")
hsize = le32(fin)

onum = le16(fin)
orst = le16(fin)
chs = le16(fin)
pnum = le16(fin)
inum = le16(fin)
flags = le16(fin)
spe = le16(fin)
tem = le16(fin)

ordl = array.array("B")
ordl.fromfile(fin, onum)
if onum == 0: # handle OpenMPT empty order list
    onum = 1
    ordl.append(0)
fin.seek(hsize + 60)

print("Tracker: " + tracker)
print("{} instruments, {} patterns and {} patterns long.".format(inum, pnum, onum))
print("[Initial] Speed {} | Tempo {}".format(spe, tem))
print("Pattern order: " + " ".join([str(i) for i in ordl]))

if tem != 150:
    print("Warning: Tempo is not 150 bpm! Adjust module speed or specify timer settings.")

# Patterns

patpl = []
for i in range(pnum):
    fpos = fin.tell()
    hsize = le32(fin)
    fin.seek(1, 1) # packing type
    rows = le16(fin)
    psize = le16(fin)
    if rows == 0:
        rows = 64
    if psize == 0: # empty pattern
        rows = 0
    fin.seek(fpos + hsize)

    patpl.append([[XMRow(fin) for k in range(chs)] for j in range(rows)])
    fin.seek(fpos + hsize + psize)

# Instruments

waves = []
for i in range(inum):
    fpos = fin.tell()
    hsize = le32(fin)
    fin.seek(23, 1) # instrument name, garbage byte
    snum = le16(fin)
    fin.seek(fpos + hsize)

    sheaders = [XMSampleHeader(fin) for j in range(snum)]
    if 4 <= i < 16:
        procdsamp = [0] * 32
        fpos = fin.tell()
        # process the first sample's data for wave
        if snum == 0:
            print("Warning: Instrument {} contains no samples!".format(i+1))
        else:
            sheader = sheaders[0]
            dtype = "B"
            ssize = sheader.size
            is16 = sheader.type & 0x10 # 16-bit sample
            if is16:
                dtype = "H"
                ssize &= ~1
            sampdata = array.array(dtype)
            sampdata.fromfile(fin, ssize)
            slen = len(sampdata)

            # decode dpcm back to pcm
            bound = 65536 if is16 else 256
            val = 32768 if is16 else 128
            for j in range(slen):
                newval = (val + sampdata[j]) % bound
                sampdata[j] = newval
                val = newval
            loopstart = sheader.loopstart
            looplen = sheader.looplen
            if looplen == 0:
                print("Warning: Instrument {}'s sample is a one-shot sample. ".format(i+1) +
                    "The first 32 samples will be read instead.")
                for j in range(min(slen, 32)):
                    procdsamp[j] = sampdata[j]
            else:
                if looplen != 32:
                    print("Warning: Instrument {}'s sample loop size is not 32 samples long (TODO)".format(i+1))
                for j in range(min(looplen, 32)):
                    procdsamp[j] = sampdata[loopstart + j]

            # TPDF dither
            random.seed(-3662269746218189933)
            for j in range(32):
                val = procdsamp[j] / bound
                ev = int(val*16)
                er = val*16 - ev
                if er > random.triangular(): ev += 1
                procdsamp[j] = min(ev, 15)
        waves.append(procdsamp)
        fin.seek(fpos)

    for j in range(snum):
        fin.seek(sheaders[j].size, 1)

fin.close()
print("Converting pattern data...")

"""
File format:

byte    patterns count
byte    pattern table size
byte    module speed
byte    tick speed
word    song data offset
byte    timer control
byte    timer modulo
ds 8    (reserved)
ds 16   song name
ds 16   song author
rept 12
    ds 16   wave data
rept pattern table size
    byte    pattern index
rept patterns count
    byte    rows count (0 = 256 rows)
    word    pattern data offset
ds ?    pattern data
"""

fou.write(struct.pack("<BBBBHBB", pnum, onum, spe, 1, 240 + onum + pnum * 3, timerModulo, timerCtrl))
fou.write(b"\x00" * 8) # reserved
nameb = name.encode()[:16]
fou.write(nameb + b" " * (16 - len(nameb)))
authorb = author.encode()[:16]
fou.write(authorb + b" " * (16 - len(authorb)))
for i in waves:
    for j in range(0, 32, 2):
        fou.write(((i[j] << 4) | i[j+1]).to_bytes(1, "little", signed=False))
fou.write(b"\x00" * (16 * (12 - len(waves))))
ordl.tofile(fou) # order list

"""
Pattern format:

hold = EMPTY_ROW
for i = 0 to rows_count - 1:
  row[i] = EMPTY_ROW
  for j = 0 to 3:
    flags = read_byte()
    if bit 0 of flags set:
        hold[j].note = read_byte()
    if bit 1 of flags set:
        hold[j].inst = read_byte()
    if bit 2 of flags set:
        hold[j].vcmd = read_byte()
    if bit 3 of flags set:
        hold[j].parm = read_byte()
    if bit 4 of flags set:
        row[i][j].note = hold[j].note
    if bit 5 of flags set:
        row[i][j].inst = hold[j].inst
    if bit 6 of flags set:
        row[i][j].vol = hold[j].vcmd >> 4
    if bit 7 of flags set:
        row[i][j].cmd = hold[j].vcmd & 0x0f
        row[i][j].parm = hold[j].parm
"""

XM_NOTE_OFF = 97
GBM_NOTE_OFF = 254
GBM_NOTE_EMPTY = 255
NOISE_NOTE_MAP = [ # C D F G#
    12, 12, 13, 13, 14, 14, 14, 15, 15, 15, 15, 16,
    16, 16, 17, 17, 18, 18, 18, 19, 19, 19, 19, 20,
    20, 20, 21, 21, 22, 22, 22, 23, 23, 23, 23, 24,
    24, 24, 25, 25, 26, 26, 26, 27, 27, 27, 27, 28,
    28, 28, 29, 29, 30, 30, 30, 31, 31, 31, 31, 32,
    32, 32, 33, 33, 34, 34, 34, 35, 35, 35, 35, 36,
    36, 36, 37, 37, 38, 38, 38, 39, 39, 39, 39, 40,
    41, 41, 41, 41, 42, 42, 42, 42, 42, 42, 43, 43
]

ptpos = fou.tell()
fou.seek(pnum * 3, 1)
hold = [0] * 16
p = 0
for i in patpl:
    rows = len(i)
    if rows < 64:
        print("ERROR: Pattern {}'s size is less than 64 rows! Use D00 to cut the pattern instead.".format(p))
        exit(1)
    elif rows > 64:
        print("ERROR: Pattern {}'s size is greater than 64 rows!".format(p))
        exit(1)
    fpos = fou.tell()
    fou.seek(ptpos)
    fou.write(struct.pack("<BH", rows, fpos))
    fou.seek(fpos)
    ptpos += 3
    p += 1

    for j in i:
        for k in range(len(j)):
            outrow = array.array("B")
            note = j[k].note
            ins = j[k].ins % 16 # TODO remove % 16
            vol = j[k].vol
            cmd = j[k].cmd
            par = j[k].par

            if note == 0 or note > XM_NOTE_OFF:
                note = GBM_NOTE_EMPTY
            elif note == XM_NOTE_OFF:
                note = GBM_NOTE_OFF
            elif k == 3: # noise
                note = NOISE_NOTE_MAP[note-1]
            else:
                if k == 2 and 0 < ins < 5: # conpensate for ch1-2 frequency
                    note = min(note + 11, 71)
                else:
                    note = min(note - 1, 71)
            if 0x10 <= vol <= 0x50:
                vol = min((vol - 0x10) // 4, 15)
                
            else:
                vol = 0 if ins == 0 else 15
                
            cmd = cmd & 0xF
                
            # TODO pattern packing
            outrow.fromlist([note, ins | (vol << 4), cmd, par])
            outrow.tofile(fou)
        for k in range(4 - len(j)):
            fou.write(b"\xff\x00\x00\x00")

fou.close()
print("Completed!\n")

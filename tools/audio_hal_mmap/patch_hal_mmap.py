#!/usr/bin/env python3
"""
Make the prebuilt Rockchip audio HAL usable with an AAudio MMAP output.

The RG DS has a single playback card (rk817-sound), so it does not need the
two-card headphone stub the RG DS Plus carries. What it does need are the three
MMAP defects that stop an AUDIO_OUTPUT_FLAG_MMAP_NOIRQ mix port from coexisting
with the AudioFlinger primary mixer. Those fixes are the same ones applied to
the Plus HAL and keep that script's numbering (steps 4 to 6 of
tools/audio_hal_headphone/patch_hal.py in the Plus vendor tree); steps 1 to 3
there are the headphone stub and are deliberately absent here. Step 7 is this
board's own, and makes an MMAP stream honour the device it was opened for.

Note the RG DS card exposes a single playback substream, so an MMAP stream and
the AudioFlinger mixer contend for the same pcm: MMAP EXCLUSIVE only succeeds
while the mixer output is in standby. When measuring, always check the sharing
mode the client reports, because AAudio falls back to the legacy path silently
and a legacy run exercises none of this.

The executable LOAD segment is still grown, because the trampolines live in the
zero padding after .plt and have to be mapped executable. Nothing moves: the
bytes grown into are existing padding.

Both boards ship the same unpatched HAL (md5 0a7dc708...), so every offset below
is shared. Every site is checked before it is written and the script refuses to
touch a binary that does not match byte for byte.

  patch_hal_mmap.py <in.so> <out.so>
"""
import struct
import sys

SRC = sys.argv[1]
DST = sys.argv[2]

PHDR_EXEC = 2
NEW_SZ = 0x2E400  # exec LOAD filesz/memsz, was 0x2e1a0

d = bytearray(open(SRC, 'rb').read())


def expect(off, val, what):
    cur, = struct.unpack_from('<I', d, off)
    if cur != val:
        sys.exit(f"refusing to patch: {what} at {off:#x} is {cur:#010x}, expected {val:#010x}")


def w32(off, val):
    struct.pack_into('<I', d, off, val)


def bl(pc, target):
    return 0x94000000 | (((target - pc) >> 2) & 0x03FFFFFF)


def b(pc, target):
    return 0x14000000 | (((target - pc) >> 2) & 0x03FFFFFF)


# --- grow the executable segment so the trampolines are mapped ---------------
e_phoff, = struct.unpack_from('<Q', d, 0x20)
e_phentsize, = struct.unpack_from('<H', d, 0x36)
ph = e_phoff + PHDR_EXEC * e_phentsize
p_type, p_flags = struct.unpack_from('<II', d, ph)
p_filesz, p_memsz = struct.unpack_from('<QQ', d, ph + 32)
if p_type != 1 or p_flags != 5:
    sys.exit(f"refusing to patch: phdr[{PHDR_EXEC}] is not the exec LOAD")
if p_filesz != 0x2E1A0:
    sys.exit(f"refusing to patch: exec LOAD filesz is {p_filesz:#x}")
struct.pack_into('<QQ', d, ph + 32, NEW_SZ, NEW_SZ)

# --- 4. an MMAP open must not free the output that already holds the slot -----
# Opening an AUDIO_OUTPUT_FLAG_MMAP_NOIRQ stream while adev->outputs[type] is
# taken (the AudioFlinger primary mixer shares OUTPUT_LOW_LATENCY with the
# mmap_no_irq_out mix port) made the HAL free() that other stream_out outright,
# without standby, without unlinking it from output_stream_list and while
# AudioFlinger still owned it. Every later mixer write or audio patch walked
# freed memory and audioserver died with the HAL. Keep the existing stream; the
# MMAP stream skips the slot and only joins the stream list.
MMAP_FREE_SITE = 0x23610
MMAP_TAIL = 0x236A0
expect(MMAP_FREE_SITE + 0x0, 0xF0FFFF41, "mmap free block adrp x1")
expect(MMAP_FREE_SITE + 0x4, 0x911D0821, "mmap free block add x1")
expect(MMAP_FREE_SITE + 0x8, 0xF0FFFF42, "mmap free block adrp x2")
expect(MMAP_FREE_SITE + 0xC, 0x9138CC42, "mmap free block add x2")
expect(0x2360C, 0xB40001C9, "mmap slot check cbz")
expect(0x23644, 0x9106E2B6, "normal path prologue")
w32(MMAP_FREE_SITE + 0x0, 0x52800028)  # mov  w8, #1
w32(MMAP_FREE_SITE + 0x4, 0xF901329F)  # str  xzr, [x20, #0x260]  out->nframes = 0
w32(MMAP_FREE_SITE + 0x8, 0x3908B288)  # strb w8, [x20, #0x22c]   out->standby = true
w32(MMAP_FREE_SITE + 0xC, b(MMAP_FREE_SITE + 0xC, MMAP_TAIL))

# --- 5. open_pcm must forget a pcm it closed --------------------------------
# open_pcm() only calls pcm_open() when out->pcm[index] is NULL. Its failure
# path closed the pcm but left the dangling pointer, so every later
# start_output_stream() skipped pcm_open(), re-tested the dead object and failed
# again until the HAL restarted. Route the close through a trampoline that also
# stores NULL (x23 = &out->pcm[index], callee saved).
OPENPCM_CLOSE = 0x27870
PCMCLOSE_PLT = 0x4D800
CAVE2 = 0x4E200
expect(OPENPCM_CLOSE - 4, 0xF94002E0, "open_pcm failure path ldr x0, [x23]")
expect(OPENPCM_CLOSE, bl(OPENPCM_CLOSE, PCMCLOSE_PLT), "open_pcm failure path bl pcm_close")
expect(OPENPCM_CLOSE + 4, 0x12800160, "open_pcm failure path mov w0, #-12")
tramp = [0xA9BF7BFD,                    # stp x29, x30, [sp, #-16]!
         bl(CAVE2 + 4, PCMCLOSE_PLT),   # bl  pcm_close
         0xF90002FF,                    # str xzr, [x23]
         0xA8C17BFD,                    # ldp x29, x30, [sp], #16
         0xD65F03C0]                    # ret
if set(d[CAVE2:CAVE2 + 4 * len(tramp)]) != {0}:
    sys.exit("refusing to patch: open_pcm trampoline target is not free")
for i, ins in enumerate(tramp):
    w32(CAVE2 + 4 * i, ins)
w32(OPENPCM_CLOSE, bl(OPENPCM_CLOSE, CAVE2))

# --- 6. an MMAP stream must close its pcm when it is stopped or closed -----
# out_create_mmap_buffer() opens out->pcm[0] directly and never clears
# out->standby, so do_out_standby() never closed it and the stream was freed
# with the pcm still open: the pcm node stayed open in the HAL and every later
# open_pcm() of the mixer output got EBUSY until the HAL restarted.
DO_OUT_STANDBY = 0x26C20
OUTSTOP_CLOSE = 0x266DC
CMB_FAIL_CLOSE = 0x26A58
CLOSE_STANDBY = 0x23750
CAVE3 = 0x4E220
T_STOP, T_CMB, T_CLOSE = CAVE3, CAVE3 + 0x20, CAVE3 + 0x40
expect(OUTSTOP_CLOSE - 4, 0xF940BA80, "out_stop ldr x0, [x20, #0x170]")
expect(OUTSTOP_CLOSE, bl(OUTSTOP_CLOSE, PCMCLOSE_PLT), "out_stop bl pcm_close")
expect(OUTSTOP_CLOSE + 4, 0x390D429F, "out_stop strb wzr, [x20, #0x350]")
expect(CMB_FAIL_CLOSE - 4, 0xF940BA60, "out_create_mmap_buffer failure ldr x0, [x19, #0x170]")
expect(CMB_FAIL_CLOSE, bl(CMB_FAIL_CLOSE, PCMCLOSE_PLT), "out_create_mmap_buffer failure bl pcm_close")
expect(CMB_FAIL_CLOSE + 4, 0x12800160, "out_create_mmap_buffer failure mov w0, #-12")
expect(CLOSE_STANDBY - 4, 0xAA1303E0, "adev_close_output_stream mov x0, x19")
expect(CLOSE_STANDBY, bl(CLOSE_STANDBY, DO_OUT_STANDBY), "adev_close_output_stream bl do_out_standby")
expect(CLOSE_STANDBY + 4, 0xAA1403E0, "adev_close_output_stream mov x0, x20")
t_stop = [0xA9BF7BFD,
          bl(T_STOP + 4, PCMCLOSE_PLT),
          0xF900BA9F,                   # str xzr, [x20, #0x170]
          0xA8C17BFD,
          0xD65F03C0]
t_cmb = [0xA9BF7BFD,
         bl(T_CMB + 4, PCMCLOSE_PLT),
         0xF900BA7F,                    # str xzr, [x19, #0x170]
         0xA8C17BFD,
         0xD65F03C0]
t_close = [0xA9BF7BFD,
           bl(T_CLOSE + 4, DO_OUT_STANDBY),
           0xF940BA60,                  # ldr x0, [x19, #0x170]
           0xB4000060,                  # cbz x0, +12
           bl(T_CLOSE + 16, PCMCLOSE_PLT),
           0xF900BA7F,                  # str xzr, [x19, #0x170]
           0xA8C17BFD,
           0xD65F03C0]
if set(d[CAVE3:T_CLOSE + 4 * len(t_close)]) != {0}:
    sys.exit("refusing to patch: mmap close trampolines target is not free")
for base, ins in ((T_STOP, t_stop), (T_CMB, t_cmb), (T_CLOSE, t_close)):
    for i, w in enumerate(ins):
        w32(base + 4 * i, w)
w32(OUTSTOP_CLOSE, bl(OUTSTOP_CLOSE, T_STOP))
w32(CMB_FAIL_CLOSE, bl(CMB_FAIL_CLOSE, T_CMB))
w32(CLOSE_STANDBY, bl(CLOSE_STANDBY, T_CLOSE))

# --- 7. an MMAP stream must open on the device it was asked for ---------------
# out_create_mmap_buffer() seeded the stream's device array with a literal
# AUDIO_DEVICE_OUT_SPEAKER and then derived the route from array[0], so every
# low latency stream came out of the speaker no matter what the policy layer had
# selected: with headphones plugged in the game stayed on the speaker. Take the
# device adev_open_output_stream() already stored in the stream instead.
#
# The substitution is deliberately narrow. Only the two wired headphone devices
# are honoured and every other value still executes the original mov, so the
# speaker case is byte for byte what the unpatched HAL does. A blanket swap was
# tried first and lost the speaker entirely.
CMB_DEV_SITE = 0x26888
STREAM_DEVICE = 560  # adev_open_output_stream: str w28, [x0, #560]
CAVE4 = 0x4E2A0
expect(CMB_DEV_SITE, 0x5280004A, "out_create_mmap_buffer mov w10, #AUDIO_DEVICE_OUT_SPEAKER")
expect(CMB_DEV_SITE + 4, 0xB9033A69, "out_create_mmap_buffer str w9, [x19, #0x338]")
expect(CMB_DEV_SITE + 8, 0xB902FA6A, "out_create_mmap_buffer str w10, [x19, #0x2f8]")
t_dev = [0xB942326A,   # ldr  w10, [x19, #560]   stream->device
         0x7100115F,   # cmp  w10, #4            AUDIO_DEVICE_OUT_WIRED_HEADSET
         0x54000080,   # b.eq +16                keep it
         0x7100215F,   # cmp  w10, #8            AUDIO_DEVICE_OUT_WIRED_HEADPHONE
         0x54000040,   # b.eq +8                 keep it
         0x5280004A,   # mov  w10, #2            otherwise the original constant
         0xD65F03C0]   # ret
if set(d[CAVE4:CAVE4 + 4 * len(t_dev)]) != {0}:
    sys.exit("refusing to patch: mmap device trampoline target is not free")
for i, ins in enumerate(t_dev):
    w32(CAVE4 + 4 * i, ins)
w32(CMB_DEV_SITE, bl(CMB_DEV_SITE, CAVE4))

open(DST, 'wb').write(d)
print(f"patched {SRC} -> {DST}")
print(f"  exec LOAD filesz/memsz {p_filesz:#x} -> {NEW_SZ:#x}")
print(f"  mmap open keeps the existing output ({MMAP_FREE_SITE:#x} -> {MMAP_TAIL:#x})")
print(f"  open_pcm clears its closed pcm via {CAVE2:#x}")
print(f"  mmap pcm closed on stop/close via {T_STOP:#x}, {T_CMB:#x}, {T_CLOSE:#x}")
print(f"  mmap stream takes its own device (headphones only) via {CAVE4:#x}")

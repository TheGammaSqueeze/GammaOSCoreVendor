#!/usr/bin/env python3
"""
Add headphone routing to the prebuilt Rockchip audio HAL.

The board has two playback cards: the AW882xx speaker amp (rockchipaw882xx) and
the RK817 codec that owns the 3.5mm jack (rockchiprk817). The HAL is a single
card design, so the jack never took the audio and the speakers never muted.
We keep every byte of the shipped behaviour and only add a second card.

  1. SPDIF_1_OUT_NAME is repointed at "rockchiprk817", so the card scan fills
     dev_out[SND_OUT_SOUND_CARD_SPDIF_1] with the RK817 card. That slot is
     otherwise dead on this board: its only consumer is a branch guarded on
     device 0x80001 (VX_ROCKCHIP_OUT_SPDIF0), which never occurs here.
  2. A stub in spare space after .plt replaces the card load at 0x259f8: it
     picks the SPEAKER slot for speakers and the SPDIF_1 slot for the jack, then
     performs the same route call and pcm open the original code performed.

The executable LOAD segment is grown to cover the stub. The bytes it grows into
are existing zero padding between .plt and the next segment, so nothing moves.
"""
import struct, subprocess, sys, os

SRC = sys.argv[1]
DST = sys.argv[2]

CAVE      = 0x4e1a0   # vaddr == file offset in the exec segment
STR_VA    = 0x4e300
BACK      = 0x25a24   # the tbnz that checks open_pcm's return
PATCH_SITE= 0x259f8   # ldr w23, [x22, #512]
MASK_SITE = 0x259d8   # mov w10, #0x114
TBL_SLOT  = 0x749c0   # SPDIF_1_OUT_NAME[0].cid
DATA_DELTA= 0x10000   # .data vaddr - file offset
GETROUTE  = 0x4d5d0   # getRouteFromDevice@plt
ROUTEOPEN = 0x4d930   # route_pcm_card_open@plt
OPENPCM   = 0x27750   # open_pcm
PHDR_EXEC = 2
NEW_SZ    = 0x2e400   # was 0x2e1a0

d = bytearray(open(SRC, 'rb').read())

def expect(off, val, what):
    cur, = struct.unpack_from('<I', d, off)
    if cur != val:
        sys.exit(f"refusing to patch: {what} at {off:#x} is {cur:#010x}, expected {val:#010x}")

def w32(off, val):
    struct.pack_into('<I', d, off, val)

def bl(pc, target):
    return 0x94000000 | (((target - pc) >> 2) & 0x03ffffff)

def b(pc, target):
    return 0x14000000 | (((target - pc) >> 2) & 0x03ffffff)

# --- assemble the stub -------------------------------------------------------
here = os.path.dirname(os.path.abspath(__file__))
subprocess.run(['aarch64-linux-gnu-as', '-o', f'{here}/stub.o', f'{here}/stub.s'], check=True)
out = subprocess.run(['aarch64-linux-gnu-objcopy', '-O', 'binary', '-j', '.text',
                      f'{here}/stub.o', f'{here}/stub.bin'], check=True)
stub = bytearray(open(f'{here}/stub.bin', 'rb').read())

# The assembler leaves the unresolved branches as bare opcodes with a zero
# displacement. Fill them in, in source order, rather than at fixed offsets.
calls = [o for o in range(0, len(stub), 4)
         if struct.unpack_from('<I', stub, o)[0] == 0x94000000]
jumps = [o for o in range(0, len(stub), 4)
         if struct.unpack_from('<I', stub, o)[0] == 0x14000000]
if len(calls) != 3 or len(jumps) != 1:
    sys.exit(f"unexpected stub shape: {len(calls)} calls, {len(jumps)} jumps")
for off, tgt in zip(calls, (GETROUTE, ROUTEOPEN, OPENPCM)):
    struct.pack_into('<I', stub, off, bl(CAVE + off, tgt))
struct.pack_into('<I', stub, jumps[0], b(CAVE + jumps[0], BACK))

# --- 1. point SPDIF_1_OUT_NAME at the RK817 card name ------------------------
slot = TBL_SLOT - DATA_DELTA
old, = struct.unpack_from('<Q', d, slot)
if old == 0:
    sys.exit("refusing to patch: SPDIF_1_OUT_NAME[0].cid is NULL, no relocation to reuse")
struct.pack_into('<Q', d, slot, STR_VA)
d[STR_VA:STR_VA + 14] = b"rockchiprk817\0"

# The device bitmask at MASK_SITE (0x114 = devices 2, 4 and 8) is deliberately
# left alone. The stub lives inside the branch that mask guards, so narrowing it
# would stop a headphone from ever reaching the stub.

# --- 3. divert the card load into the stub -----------------------------------
expect(PATCH_SITE, 0xb94202d7, "speaker card load")
w32(PATCH_SITE, b(PATCH_SITE, CAVE))

# --- place the stub and grow the executable segment --------------------------
if set(d[CAVE:CAVE + len(stub)]) != {0}:
    sys.exit("refusing to patch: stub target is not free")
d[CAVE:CAVE + len(stub)] = stub

e_phoff, = struct.unpack_from('<Q', d, 0x20)
e_phentsize, = struct.unpack_from('<H', d, 0x36)
ph = e_phoff + PHDR_EXEC * e_phentsize
p_type, p_flags = struct.unpack_from('<II', d, ph)
p_filesz, p_memsz = struct.unpack_from('<QQ', d, ph + 32)
if p_type != 1 or p_flags != 5:
    sys.exit(f"refusing to patch: phdr[{PHDR_EXEC}] is not the exec LOAD")
if p_filesz != 0x2e1a0:
    sys.exit(f"refusing to patch: exec LOAD filesz is {p_filesz:#x}")
struct.pack_into('<QQ', d, ph + 32, NEW_SZ, NEW_SZ)

# --- 4. an MMAP open must not free the output that already holds the slot -----
# Opening an AUDIO_OUTPUT_FLAG_MMAP_NOIRQ stream while adev->outputs[type] is
# taken (the AudioFlinger primary mixer shares OUTPUT_LOW_LATENCY with the
# mmap_no_irq_out mix port) made the HAL free() that other stream_out outright,
# without standby, without unlinking it from output_stream_list and while
# AudioFlinger still owned it. Every later mixer write or audio patch walked
# freed memory (pcm_write, audio_effect_process, adev_create_audio_patch
# crashes) and audioserver died with the HAL. Keep the existing stream; the
# MMAP stream skips the slot and only joins the stream list (same tail the
# normal path runs: list add, effects list init, *stream_out).
MMAP_FREE_SITE = 0x23610   # first instruction of the "mmap close already open output" block
MMAP_TAIL      = 0x236a0   # adev_add_stream_to_list(...) in adev_open_output_stream
expect(MMAP_FREE_SITE + 0x0, 0xf0ffff41, "mmap free block adrp x1")
expect(MMAP_FREE_SITE + 0x4, 0x911d0821, "mmap free block add x1")
expect(MMAP_FREE_SITE + 0x8, 0xf0ffff42, "mmap free block adrp x2")
expect(MMAP_FREE_SITE + 0xc, 0x9138cc42, "mmap free block add x2")
expect(0x2360c, 0xb40001c9, "mmap slot check cbz")
expect(0x23644, 0x9106e2b6, "normal path prologue")
w32(MMAP_FREE_SITE + 0x0, 0x52800028)              # mov  w8, #1
w32(MMAP_FREE_SITE + 0x4, 0xf901329f)              # str  xzr, [x20, #0x260]   out->nframes = 0
w32(MMAP_FREE_SITE + 0x8, 0x3908b288)              # strb w8, [x20, #0x22c]    out->standby = true
w32(MMAP_FREE_SITE + 0xc, b(MMAP_FREE_SITE + 0xc, MMAP_TAIL))

# --- 5. open_pcm must forget a pcm it closed --------------------------------
# open_pcm() only calls pcm_open() when out->pcm[index] is NULL. Its failure
# path (pcm not ready) logged, called pcm_close() and returned -ENOMEM but left
# the dangling pointer in place, so every later start_output_stream() on that
# stream skipped pcm_open(), re-tested the dead object, printed the stale error
# and failed again, every 10 ms, until the HAL restarted. Any transient open
# failure (the exclusive MMAP stream holding the card for a moment) therefore
# killed the primary mixer output for the rest of the boot: never in standby,
# never audible, tracks never draining. The pcm_close call now goes through a
# trampoline that also stores NULL (x23 = &out->pcm[index] is callee saved).
OPENPCM_CLOSE = 0x27870   # bl pcm_close in open_pcm's failure path
PCMCLOSE_PLT  = 0x4d800
CAVE2         = 0x4e200   # after the headphone stub, before its string
expect(OPENPCM_CLOSE - 4, 0xf94002e0, "open_pcm failure path ldr x0, [x23]")
expect(OPENPCM_CLOSE, bl(OPENPCM_CLOSE, PCMCLOSE_PLT), "open_pcm failure path bl pcm_close")
expect(OPENPCM_CLOSE + 4, 0x12800160, "open_pcm failure path mov w0, #-12")
tramp = [0xa9bf7bfd,                       # stp x29, x30, [sp, #-16]!
         bl(CAVE2 + 4, PCMCLOSE_PLT),      # bl  pcm_close
         0xf90002ff,                       # str xzr, [x23]
         0xa8c17bfd,                       # ldp x29, x30, [sp], #16
         0xd65f03c0]                       # ret
if set(d[CAVE2:CAVE2 + 4 * len(tramp)]) != {0}:
    sys.exit("refusing to patch: open_pcm trampoline target is not free")
for i, ins in enumerate(tramp):
    w32(CAVE2 + 4 * i, ins)
w32(OPENPCM_CLOSE, bl(OPENPCM_CLOSE, CAVE2))

open(DST, 'wb').write(d)
print(f"patched {SRC} -> {DST}")
print(f"  stub at {CAVE:#x} ({len(stub)} bytes), string at {STR_VA:#x}")
print(f"  exec LOAD filesz/memsz {p_filesz:#x} -> {NEW_SZ:#x}")
print(f"  mmap open keeps the existing output ({MMAP_FREE_SITE:#x} -> {MMAP_TAIL:#x})")
print(f"  open_pcm clears its closed pcm via {CAVE2:#x}")

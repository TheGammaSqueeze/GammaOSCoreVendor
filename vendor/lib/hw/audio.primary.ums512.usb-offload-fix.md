# RG Rotate USB Audio Fix (SPRD USB/TypeC offload)

**Component:** `vendor/lib/hw/audio.primary.ums512.so` (Unisoc/SPRD primary audio HAL)
**Device:** Anbernic RG Rotate (`ums512` / SC9863A)
**Type:** In-place binary patch (20 bytes), size-preserving, no section/relocation changes
**Status:** Applied, flashed and confirmed working on device

> Credit for the original discovery and workaround goes to **PPDeluXe** (https://github.com/PPDeluXe1),
> who authored the "RG Rotate Universal USB Audio Fix" Magisk module. This patch resolves the same
> problem at its source in the vendor HAL. Their analysis and validated device list made this fix
> straightforward to land.

## Symptom

Many generic USB Audio Class (UAC) DAC dongles and USB-C headsets produce broken or no audio on the
RG Rotate. Affected devices confirmed by the original module author include the Jabra Evolve2 30 SE,
the Generic Odyssey Retro by VECLAN, and the UGREEN CM721.

## Root Cause

This is a Unisoc/SPRD vendor behavior, not a GammaOS frameworks issue. The stock primary audio HAL
implements a "USB-C digital audio offload" path that routes USB-C headset audio through the SPRD DSP.
On USB-C audio it probes the card and, when it decides the device supports offload, sets three kernel
ALSA mixer controls:

- `USB_AUD_OFLD_P_EN` = 1  (playback offload enable)
- `USB_AUD_OFLD_C_EN` = 1  (capture offload enable)
- `USB_AUD_SHOULD_SUSPEND`

Setting these flips the SPRD USB-audio kernel driver into "offload mode 1", which races the normal
generic `snd_usb_endpoint_start()` path and breaks UAC devices. The working state is "offload mode 0"
(generic endpoint startup, no DSP offload). Stock AOSP frameworks route USB audio through the generic
`usb` HAL module; the SPRD path parasitically hijacks the routing through those kernel controls.

## The Original Fix (PPDeluXe Magisk module)

The module `veclan_usb_audio_fix` (author PPDeluXe, version 1.2.0) leaves the HAL untouched and acts as
a runtime referee above it. A small native ARM64 helper watches `/dev/snd` for USB/ALSA hotplug, and
for any card exposing all three SPRD controls it:

1. Resolves the controls by name (no VID/PID or fixed card ID).
2. Forces all three Off before endpoint startup.
3. Holds userspace ownership with ALSA `ELEM_LOCK` so the vendor HAL cannot race playback offload back On.
4. Keeps the control fd open so the locks stay held while the USB card is attached.
5. Falls back to a low-overhead direct-ioctl / `tinymix` loop if a control cannot be locked.

The kernel trace the author used to confirm success shows the endpoint starting with
`sprd_usb_audio_offload_check usb stream=playback, enter offload mode 0`.

## This Patch

Instead of continuously overriding the HAL's decision at runtime, this patch removes the decision.
Two functions in the HAL are the sole gates for USB/TypeC offload:

- `check_supprot_typec_offload` is the only writer of the playback offload-active flag at `dev+0x7f8`.
  `open_usboutput_channel` opens the DSP offload channel only when that flag is set.
- `check_supprot_typec_record` is the only writer of the capture offload-active flag at `dev+0x7f9`
  (also read by `is_usbmic_offload_supported`). `open_usbinput_channel` gates on that flag.

Both functions are stubbed to clear their flag and return 0 ("offload not supported") which is a
first-class state the HAL already handles by falling back to the generic USB path. With the flags never
set, the HAL never opens the offload channels and never writes `USB_AUD_OFLD_*_EN` to 1, so the kernel
stays in offload mode 0. `USB_AUD_SHOULD_SUSPEND` is only touched inside the now-skipped offload channel
open/close, so it is left untouched as well.

Both entry points take the device pointer in `r0`. The replacement (Thumb-2) is:

- `check_supprot_typec_offload` at file offset `0x3b0f4`
  - before: `2d e9 f0 4f 85 b0 04 46 8f 48`
  - after:  `00 21 80 f8 f8 17 00 20 70 47`  (movs r1,#0 ; strb.w r1,[r0,#0x7f8] ; movs r0,#0 ; bx lr)
- `check_supprot_typec_record` at file offset `0x3b43c`
  - before: `2d e9 f0 4f 85 b0 04 46 b0 48`
  - after:  `00 21 80 f8 f9 17 00 20 70 47`  (movs r1,#0 ; strb.w r1,[r0,#0x7f9] ; movs r0,#0 ; bx lr)

Only these 20 instruction bytes change. The ELF layout, symbol table and relocations are untouched.
Built-in speaker and headphone audio are unaffected because these functions are USB/TypeC specific.

- Stock HAL md5:   `d8b478ce45e18249623d97ee3d16ed0f`
- Patched HAL md5: `f50434440c868fed9f3f989f33e68cb5`

## Patch vs Module: Trade-offs

Both approaches fix the same race at different points in the chain. For a distribution image we control
and ship, the patch is preferred; the module remains the better tool when the image cannot be modified.

**Why the patch is preferred here**

- No race: the enable code path is gone, so there is no timing-sensitive first-connect moment to lose.
  The module's design is specifically about winning a race against `snd_usb_endpoint_start()`.
- No resident process: the module keeps a native guard (plus a shell fallback loop) alive holding a
  control fd for as long as the USB card is attached. The patch adds zero runtime cost.
- Ships in the image: present on a clean flash, needs no root and no Magisk, and cannot be knocked out
  by an OTA resetting module state or by Magisk being absent.
- Consistent HAL state: the HAL genuinely takes the non-offload path rather than believing it enabled
  offload while an external lock yanks the controls back.

**Where the module has the edge**

- Reversibility: disable the module and reboot to return to bone-stock behavior. Reverting the patch
  means reflashing the stock HAL (a backup is kept alongside this build).
- Update resilience: the module keys off control names, so it keeps working across new Unisoc HAL
  builds. This patch is tied to byte offsets in this specific `audio.primary.ums512.so` and must be
  re-derived if the HAL binary is ever updated.
- Portability: one module works on any device exposing the three controls; this patch is specific to
  this binary and device.

## Using the Module On Top of This Patch

Supported and harmless. The three controls are ALSA controls registered by the SPRD kernel driver on
the USB sound card, not created by the HAL. This patch only stops the userspace HAL from writing 1 to
them; it does not remove the kernel controls. If the module is installed on top, it still discovers the
controls at hotplug, finds them already Off, and locks them Off. Because the patched HAL never writes to
them, there is no write contention. The module simply reinforces a state that is already correct.

## Verification

Flash the vendor image, plug in a USB-C DAC or headset, and play audio. Confirm in `dmesg`:

    sprd_usb_audio_offload_check usb stream=playback, enter offload mode 0

and that `tinymix` shows `USB_AUD_OFLD_P_EN` / `USB_AUD_OFLD_C_EN` at 0 while audio plays.

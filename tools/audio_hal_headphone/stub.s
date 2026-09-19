// Runs in place of the single instruction at 0x259f8 (the speaker branch of the
// inlined start_output_stream). Picks dev_out[SPEAKER] for the speakers and
// dev_out[SPDIF_1] for a wired headset/headphone, then does the route call and
// the pcm open that the original code did, and returns to the error check.
//
// Live on entry: w8 = out->devices[i], w25 = the value the original code passed
// to getRouteFromDevice, x21 = out, x22 = adev, x26 = &out->devices[i]. w23 is
// dead here (the loop re-derives it) and is callee saved, so it survives the
// calls and carries our slot offset.
//
// The speakers keep w25 verbatim so their routing is bit for bit what it was.
// w25 is device | 0x400, which getOutputRouteFromDevice does not recognise (it
// only decodes raw devices 0x2 to 0x40), so it yields a generic route. That is
// harmless for the amp, which has no Playback Path control, but it would leave
// the codec muted. The jack therefore passes the raw device instead, which maps
// to route 8 for a headphone and route 14 for a headset.
.text
        mov     w23, #512               // offsetof(adev, dev_out[SPEAKER].card)
        mov     w10, w25                // route argument the original code used
        cmp     w8, #0x4                // AUDIO_DEVICE_OUT_WIRED_HEADSET
        b.eq    1f
        cmp     w8, #0x8                // AUDIO_DEVICE_OUT_WIRED_HEADPHONE
        b.ne    2f
1:      mov     w23, #608               // offsetof(adev, dev_out[SPDIF_1].card)
        mov     w10, w8                 // raw device, so the codec route resolves
2:      mov     w0, w10
        bl      getRouteFromDevice
        mov     w1, w0
        add     x9, x22, w23, uxtw
        ldr     w0, [x9]                // dev_out[slot].card
        bl      route_pcm_card_open
        add     x9, x22, w23, uxtw
        ldr     w0, [x9]                // card
        ldr     w1, [x9, #4]            // device
        cmp     w23, #512
        mov     w12, #4                 // SND_OUT_SOUND_CARD_SPDIF_1
        csel    w2, wzr, w12, eq
        mov     x3, x21
        bl      open_pcm
        b       back

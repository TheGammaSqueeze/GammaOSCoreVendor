# RP Duo dtbo

`dtbo.img` is the stock dtbo (RPDuo_20260930) with two panel changes, in
every one of its 155 entries that carries the panels (90):

1. Top panel (vtdr6130) DDIC frame timing, register B1 on page 0x10
   (`patch_top_b1.py`): the 120 Hz group gets 533 clocks per line and a
   26-line front porch, the 60 Hz group a 1985-line front porch. Stock runs
   the top at 119.44 / 59.67 Hz against the bottom's 119.78 / 59.90 Hz (a
   frame slip every 3-4 s); this centre matches the bottom, and
   `panelsync` holds the lock from there. It applies after a sleep/wake:
   at cold boot the bootloader sets the panel up from its own tables, and
   panelsync writes the same values once it starts.
2. Bottom panel (il97680a) 60 Hz host timing (`patch_bottom_vfp.py`):
   vertical front porch 12 -> 1010 lines, so the 60 Hz mode keeps the 120 Hz
   DSI link rate, as the top panel's 60 Hz timing does. With the stock porch
   the link ran at half rate and every frame took ~15.75 ms to send; a
   commit then waited ~8 ms for the previous transfer and kicked off
   ~1.5 ms before the TE, so bottom frames regularly landed a refresh late
   (drastic-nano: 0.5-2 refused bottom flips a second; 0 after the change).

Rebuild from the stock image:

    avbtool.py erase_footer --image dtbo.img            # on a copy of stock
    python3 patch_top_b1.py dtbo.img dtbo_b1.img
    python3 patch_bottom_vfp.py dtbo_b1.img dtbo_new.img 1010
    avbtool.py add_hash_footer --image dtbo_new.img --partition_name dtbo \
        --partition_size 50331648 --algorithm NONE

Flash from fastbootd: `fastboot flash dtbo dtbo.img`.

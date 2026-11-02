# Sets the vtdr6130 (top panel) DDIC frame timing in every dtbo entry: page
# 0x10 register B1, one group per refresh mode,
#   <clocks per line:16> <vbp:16> <vfp:16> 00
# 120 Hz group 534/20/28 -> 533/20/26, 60 Hz group 534/20/2000 -> 534/20/1985,
# the measured centre where the top runs at the bottom panel's rate
# (panelsync then holds it there). Same length, patched in place.
import sys
src, dst = sys.argv[1], sys.argv[2]
old = bytes.fromhex('b10216001400 1c00 0216001407d000 0216001400 1000'.replace(' ', ''))
new = bytes.fromhex('b10215001400 1a00 0216001407c100 0216001400 1000'.replace(' ', ''))
b = open(src, 'rb').read()
print('occurrences', b.count(old))
open(dst, 'wb').write(b.replace(old, new))

# In every dtbo entry, set qcom,mdss-dsi-v-front-porch of the il97680a (xingxing)
# panel's 60 Hz timing to NEW_VFP so its 60 Hz mode keeps the 120 Hz DSI link
# rate (like the vtdr6130's 60 Hz timing does), in place (same size).
import struct, sys
src, dst, NEW_VFP = sys.argv[1], sys.argv[2], int(sys.argv[3])
img = bytearray(open(src, 'rb').read())
magic, total, hsz, esz, cnt, eoff = struct.unpack_from('>IIIIII', img, 0)
assert magic == 0xd7b7ab1e
FDT_BEGIN, FDT_END_NODE, FDT_PROP, FDT_NOP, FDT_END = 1, 2, 3, 4, 9
patched = 0
for e in range(cnt):
    dsize, doff = struct.unpack_from('>II', img, eoff + e * esz)
    base = doff
    m, tsz, off_struct, off_strings = struct.unpack_from('>IIII', img, base)
    assert m == 0xd00dfeed
    p = base + off_struct
    path = []
    while True:
        tok, = struct.unpack_from('>I', img, p); p += 4
        if tok == FDT_BEGIN:
            end = img.index(b'\0', p); path.append(img[p:end].decode()); p = base + ((end + 1 - base + 3) & ~3)
        elif tok == FDT_END_NODE:
            path.pop()
        elif tok == FDT_PROP:
            ln, nameoff = struct.unpack_from('>II', img, p); p += 8
            sn = base + off_strings + nameoff
            name = img[sn:img.index(b'\0', sn)].decode()
            if (name == 'qcom,mdss-dsi-v-front-porch' and len(path) >= 3 and path[-1] == 'timing@1'
                    and 'xingxing' in path[-3] and ln == 4):
                old, = struct.unpack_from('>I', img, p)
                if old != 12:
                    print('entry %d: unexpected vfp %d at %s, skipped' % (e, old, '/'.join(path)))
                else:
                    struct.pack_into('>I', img, p, NEW_VFP); patched += 1
            p = base + ((p + ln - base + 3) & ~3)
        elif tok == FDT_NOP:
            pass
        elif tok == FDT_END:
            break
        else:
            raise SystemExit('bad token %d in entry %d' % (tok, e))
open(dst, 'wb').write(img)
print('patched', patched)

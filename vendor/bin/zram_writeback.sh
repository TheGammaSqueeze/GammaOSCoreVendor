#!/system/bin/sh
# GammaOS zram writeback (RG DS Plus, 1GB): keep zram's RAM footprint small by moving
# pages to the card-backed backing device (the 2GB 'swap' partition, set as
# /sys/block/zram0/backing_dev at `on fs`). Two kinds of page go:
#   huge  - pages lz4 could not compress (game data, textures): zram stores those 1:1,
#           so keeping them in RAM costs exactly what the page cost before it was
#           swapped. Written back every cycle.
#   idle  - pages nobody touched for a whole cycle: marked idle one cycle, written
#           back the next if still untouched. Cold anonymous memory of parked apps
#           and the home goes to the card and the RAM serves the foreground app.
# A page written back is read from the card only if it is touched again (a few ms
# per fault on this SD, against microseconds from zram), so the interval is kept
# long enough that a game's periodically used data is not evicted. Card wear is
# bounded by the writeback_limit budget renewed each cycle (4K pages).
Z=/sys/block/zram0
INTERVAL=20
BUDGET_PAGES=16384     # 64MB per cycle at most
n=0
while true; do
    sleep $INTERVAL
    [ -e $Z/writeback ] || continue
    echo $BUDGET_PAGES > $Z/writeback_limit 2>/dev/null
    echo huge > $Z/writeback 2>/dev/null
    n=$((n + 1))
    case $((n % 3)) in
        0) echo all > $Z/idle 2>/dev/null ;;
        1) echo idle > $Z/writeback 2>/dev/null ;;
    esac
done

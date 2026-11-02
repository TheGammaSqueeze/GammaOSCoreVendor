/*
 * panelsync - lock the RP Duo's top panel refresh to the bottom panel.
 *
 * Both panels are command-mode DSI panels whose refresh comes from each
 * DDIC's own oscillator (TE), so they free-run against each other: stock
 * top 119.44 / 59.67 Hz, bottom 119.78 / 59.90 Hz, a frame slip every 3 to
 * 4 seconds, and the bottom alone wanders several hundred ppm.
 *
 * The top DDIC (Visionox vtdr6130) frame is (clocks per line) x (lines),
 * set by register B1 on page 0x10: one group per refresh mode,
 *   <clocks per line:16> <vbp:16> <vfp:16> 00
 * group 1 = 120 Hz, group 2 = 60 Hz, group 3 unused here. One line is
 * about 4.25 us of frame time (509 ppm at 120 Hz, 254 ppm at 60 Hz).
 *
 * This daemon waits on the vblank of both CRTCs (no DRM master needed),
 * measures the top's phase against the bottom and steers the top's vfp a
 * few lines either side of the tuned centre, holding both panels on the
 * same vblank. Commands go through /dev/dsi_dcs0 (dsi_dcs.ko), or the
 * connector debugfs tx_cmd when the module is not loaded.
 *
 * The bootloader brings the panel up from its own tables at cold boot and
 * the kernel takes it over without resending the DT on-commands, so the
 * first write here is also what applies the tuned centre after boot.
 *
 * Usage: panelsync [debug]
 * Props: persist.gammaos.panelsync (default 1; 0 stops the loop)
 *        sys.gammaos.panelsync.offset_us (runtime, set by drastic-nano's panel
 *        phase lock) or persist.gammaos.panelsync.offset_us: how far the bottom's
 *        vblank trails the top's (default 0)
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <math.h>
#include <pthread.h>
#include <time.h>
#include <sys/ioctl.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <drm/drm.h>
#include <sys/system_properties.h>

#define TOP_CRTC      0
#define BOT_CRTC      1
#define TOP_TX        "/sys/kernel/debug/dri/0/DSI-1/tx_cmd"
#define DEBUGFS       "/sys/kernel/debug"

/* Tuned centres (measured 2026-11-02): oscillator about 125.53 MHz. */
#define C120          533     /* clocks per line, 120 Hz group */
#define VFP120        26      /* lines: 1920 + 20 + 26 = 1966 */
#define C60           534
#define VFP60         1985    /* lines: 1920 + 20 + 1985 = 3925 */
#define VBP           20
#define STEER_MAX     40      /* lines either side of the centre: a new phase is
                               * reached within about a second */
#define VFP_MIN       8       /* never shorter than this front porch */
#define GAIN          0.04    /* share of the phase error corrected per frame */
#define MIN_WRITE_NS  50000000LL
#define DCS_DEV       "/dev/dsi_dcs0"   /* dsi_dcs.ko: no global display lock */

static int debug;

typedef struct {
    pthread_mutex_t lock;
    int64_t t;          /* last vblank, ns (CLOCK_MONOTONIC) */
    uint32_t seq;
    int valid;
} vbl_t;

static vbl_t top_v = { PTHREAD_MUTEX_INITIALIZER, 0, 0, 0 };

static int64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

static int prop_int(const char *name, int def) {
    char v[PROP_VALUE_MAX] = "";
    if (__system_property_get(name, v) <= 0) return def;
    return atoi(v);
}

static int prop_enabled(void) {
    char v[PROP_VALUE_MAX] = "";
    __system_property_get("persist.gammaos.panelsync", v);
    return v[0] == 0 || strcmp(v, "0") != 0;
}

/* One vblank wait; returns 0 and the timestamp, or -errno. */
static int wait_vblank(int fd, int crtc, int64_t *t, uint32_t *seq) {
    union drm_wait_vblank vb;
    memset(&vb, 0, sizeof(vb));
    vb.request.type = _DRM_VBLANK_RELATIVE;
    if (crtc == 1) vb.request.type |= _DRM_VBLANK_SECONDARY;
    else if (crtc > 1)
        vb.request.type |= (crtc << _DRM_VBLANK_HIGH_CRTC_SHIFT) & _DRM_VBLANK_HIGH_CRTC_MASK;
    vb.request.sequence = 1;
    if (ioctl(fd, DRM_IOCTL_WAIT_VBLANK, &vb) < 0) return -errno;
    *t = (int64_t)vb.reply.tval_sec * 1000000000LL + (int64_t)vb.reply.tval_usec * 1000LL;
    *seq = vb.reply.sequence;
    return 0;
}

static void *top_thread(void *arg) {
    int fd = *(int *)arg;
    for (;;) {
        int64_t t; uint32_t s;
        int rc = wait_vblank(fd, TOP_CRTC, &t, &s);
        pthread_mutex_lock(&top_v.lock);
        if (rc == 0) { top_v.t = t; top_v.seq = s; top_v.valid = 1; }
        else top_v.valid = 0;
        pthread_mutex_unlock(&top_v.lock);
        if (rc) usleep(200000);
    }
    return NULL;
}

static int ensure_debugfs(void) {
    if (access(TOP_TX, W_OK) == 0) return 0;
    mount("debugfs", DEBUGFS, "debugfs", 0, NULL);
    return access(TOP_TX, W_OK);
}

/* Writes page 0x10 B1: the active mode's group gets vfp centre + steer,
 * the other group its centre.
 * Through /dev/dsi_dcs0 (dsi_dcs.ko) when loaded: the display driver's
 * debugfs tx_cmd holds the SDE kms VM lock for the whole transfer (40-70 ms),
 * stalling commits on BOTH panels, so every correction cost a bottom frame.
 * The module sends the same packets under only the top display's own locks
 * (0.2 ms typical). */
static int write_b1(int mode120, int steer) {
    int v120 = VFP120 + (mode120 ? steer : 0);
    int v60  = VFP60  + (mode120 ? 0 : steer);
    const unsigned char pkt[] = {
        0x39, 0x01, 0x00, 0x00, 0x00, 0x00, 0x03, 0xf0, 0xaa, 0x10,
        0x39, 0x01, 0x00, 0x00, 0x00, 0x00, 0x16, 0xb1,
        C120 >> 8, C120 & 0xff, 0x00, VBP, v120 >> 8, v120 & 0xff, 0x00,
        C60 >> 8, C60 & 0xff, 0x00, VBP, v60 >> 8, v60 & 0xff, 0x00,
        0x02, 0x16, 0x00, 0x14, 0x00, 0x10, 0x00,
        0x39, 0x01, 0x00, 0x00, 0x00, 0x00, 0x03, 0xf0, 0xaa, 0x00 };
    int fd = open(DCS_DEV, O_WRONLY | O_CLOEXEC);
    if (fd >= 0) {
        int rc = write(fd, pkt, sizeof(pkt)) == (ssize_t)sizeof(pkt) ? 0 : -errno;
        close(fd);
        return rc;
    }
    char buf[512];
    int n = 0;
    for (size_t i = 0; i < sizeof(pkt); i++)
        n += snprintf(buf + n, sizeof(buf) - n, "%s0x%02x", i ? " " : "", pkt[i]);
    fd = open(TOP_TX, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return -errno;
    int rc = write(fd, buf, (size_t)n) == n ? 0 : -errno;
    close(fd);
    return rc;
}

static int ensure_writer(void) {
    if (access(DCS_DEV, W_OK) == 0) return 0;
    return ensure_debugfs();
}

int main(int argc, char **argv) {
    debug = argc > 1 && strcmp(argv[1], "debug") == 0 ? 1 : argc > 1 && strcmp(argv[1], "trace") == 0 ? 2 : 0;
    setvbuf(stdout, NULL, _IOLBF, 0);

    int fd_top = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    int fd_bot = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (fd_top < 0 || fd_bot < 0) { perror("panelsync: open card0"); return 1; }
    pthread_t th;
    pthread_create(&th, NULL, top_thread, &fd_top);

    double p_bot = 0, p_top0 = 0;       /* smoothed bottom period, top period at steer 0 */
    int64_t last_bot = 0, last_top = 0, last_write = 0, last_prop = 0;
    uint32_t last_bot_seq = 0, last_top_seq = 0;
    int steer = 0, applied = 0, mode120 = -1, frames = 0, writes = 0;
    double err_avg = 0;
    int offset_us = 0;

    for (;;) {
        if (!prop_enabled()) {
            if (applied && mode120 >= 0) write_b1(mode120, 0);
            applied = 0; steer = 0; mode120 = -1;
            sleep(2);
            continue;
        }
        int64_t tb; uint32_t sb;
        int rc = wait_vblank(fd_bot, BOT_CRTC, &tb, &sb);
        if (rc) {
            /* Panels off (sleep) or mid-modeset: the DDIC gets its DT
             * on-commands again at wake, so start over from the centre. */
            applied = 0; p_bot = 0; p_top0 = 0; last_bot = 0; last_top = 0;
            steer = 0; mode120 = -1; frames = 0; err_avg = 0;
            usleep(200000);
            continue;
        }
        int64_t tt; uint32_t st; int tv;
        pthread_mutex_lock(&top_v.lock);
        tt = top_v.t; st = top_v.seq; tv = top_v.valid;
        pthread_mutex_unlock(&top_v.lock);

        /* bottom period, sequence aware */
        if (last_bot && sb != last_bot_seq) {
            double per = (double)(tb - last_bot) / (double)(sb - last_bot_seq);
            if (p_bot == 0 || fabs(per - p_bot) > p_bot * 0.2) p_bot = per;
            else p_bot += (per - p_bot) * 0.05;
        }
        last_bot = tb; last_bot_seq = sb;
        if (!tv || p_bot == 0) continue;

        int m120 = p_bot < 12.0e6;
        if (m120 != mode120) {
            /* refresh mode changed (or first frame): back to the centre */
            mode120 = m120; steer = 0; p_top0 = 0; last_top = 0; frames = 0; err_avg = 0;
            if (ensure_writer() == 0 && write_b1(mode120, 0) == 0) {
                applied = 1;
                last_write = now_ns();
                printf("panelsync: %s Hz mode, centre applied (%s)\n", mode120 ? "120" : "60",
                       access(DCS_DEV, W_OK) == 0 ? DCS_DEV : TOP_TX);
            } else {
                printf("panelsync: no DCS path (%s or %s), idle\n", DCS_DEV, TOP_TX);
                applied = 0;
                sleep(5);
                mode120 = -1;
                continue;
            }
        }
        double lines = mode120 ? (1940 + VFP120) : (1940 + VFP60);

        /* top period at steer 0, from the top's own vblanks */
        if (last_top && st != last_top_seq) {
            double per = (double)(tt - last_top) / (double)(st - last_top_seq);
            double base = per * lines / (lines + steer);
            if (p_top0 == 0 || fabs(base - p_top0) > p_top0 * 0.2) p_top0 = base;
            else p_top0 += (base - p_top0) * 0.05;
        }
        if (st != last_top_seq) { last_top = tt; last_top_seq = st; }
        if (p_top0 == 0) continue;

        int64_t now = now_ns();
        if (now - last_prop > 250000000LL) {
            offset_us = prop_int("sys.gammaos.panelsync.offset_us",
                                 prop_int("persist.gammaos.panelsync.offset_us", 0));
            last_prop = now;
        }
        /* phase of the top's latest vblank against the bottom's (wanted:
         * offset_us before it), wrapped */
        double e = (double)(tt - tb) + offset_us * 1000.0;
        while (e > p_bot / 2) e -= p_bot;
        while (e < -p_bot / 2) e += p_bot;
        err_avg += (e - err_avg) * 0.1;

        /* Wanted top period: the bottom's, minus a share of the phase error
         * (top late -> shorter frames). Lines = (period / base - 1) x lines. */
        double want = p_bot - GAIN * err_avg;
        int s = (int)lround((want / p_top0 - 1.0) * lines);
        if (s > STEER_MAX) s = STEER_MAX;
        if (s < -STEER_MAX) s = -STEER_MAX;
        if ((mode120 ? VFP120 : VFP60) + s < VFP_MIN) s = VFP_MIN - (mode120 ? VFP120 : VFP60);
        if (s != steer && now - last_write >= MIN_WRITE_NS) {
            if (write_b1(mode120, s) == 0) {
                steer = s; last_write = now; writes++;
                if (debug > 1) printf("write at %lld: steer %+d\n", (long long)(now / 1000), s);
            }
        }
        if (debug && (++frames % (mode120 ? 120 : 60)) == 0)
            printf("bot %.3f Hz top0 %.3f Hz steer %+d phase %+.0f us writes %d\n",
                   1e9 / p_bot, 1e9 / p_top0, steer, err_avg / 1000.0, writes);
    }
    return 0;
}

/*
 * RetroidPad.c - Retroid Pocket MCU gamepad bridge (Retroid Pocket Duo build)
 *
 * Reads the controller MCU packet stream on /dev/ttyHS1 (115200 8N1) and
 * exposes it as a uinput gamepad:
 *   face buttons, Select/Start, thumb clicks, Back (KEY_BACK) and Home (BTN_MODE)
 *   L1/R1 (digital), L2/R2 analog as ABS_BRAKE/ABS_GAS 0..255, plus BTN_TL2/BTN_TR2
 *   once a trigger is pressed past TRIG_PRESS_PCT (released below TRIG_RELEASE_PCT)
 *   D-pad as ABS_HAT0X/ABS_HAT0Y
 *   left stick ABS_X/ABS_Y, right stick ABS_Z/ABS_RZ (auto-centred at start)
 *
 * Packet: A5 D3 5A 3D <seq> <cmd> <len lo> <len hi> <data...> <xor checksum>
 * cmd 0x02 len 14: d[0..1] buttons, d[2..3] L2, d[4..5] R2 (uint16 hall sensors,
 *                  about 1880 at rest),
 *                  d[6..7] LX, d[8..9] LY, d[10..11] RX, d[12..13] RY (int16)
 *
 * Build:
 *   clang --target=aarch64-linux-android29 --sysroot=<ndk sysroot> -O2 \
 *         -fPIE -pie -o retroidpad RetroidPad.c
 * Run (as root):
 *   retroidpad "Retroid Pocket Controller" [debug]   (debug prints raw packets)
 */
#define _POSIX_C_SOURCE 199309L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <linux/uinput.h>
#include <time.h>
#include <sys/time.h>
#include <stdint.h>
#include <sys/select.h>

#define SERIAL_PATH      "/dev/ttyHS1"
#define STICK_CLIP       850     /* raw units each side of centre; the Duo Lite sticks
                                  * travel about 880 to 1000 raw units from centre */
#define STICK_FLAT       60      /* uinput flat (dead zone) */
#define STICK_FUZZ       8
#define STICK_CAL_FRAMES 50      /* packets averaged for the centre */

#define TRIG_MAX         255     /* ABS_BRAKE / ABS_GAS range */
#define TRIG_SPAN_MIN    1500    /* raw travel assumed for a full press until a deeper
                                  * press is seen (the Duo travels about 1650 to 1690:
                                  * 1880 at rest down to 190..230); the span then
                                  * follows the real travel */
#define TRIG_DIR_LOCK    150     /* raw travel from rest that fixes the press direction */
#define TRIG_DEAD_PCT    4       /* travel below this % of the span reads 0 */
#define TRIG_PRESS_PCT   60      /* BTN_TL2/BTN_TR2 down at this % ... */
#define TRIG_RELEASE_PCT 45      /* ... and up again below this % (hysteresis) */

typedef struct {
    int rest;     /* raw value at rest, averaged with the stick centres */
    int dir;      /* +1 or -1 once known: which way the raw value moves on a press */
    int span;     /* raw travel of a full press */
    int value;    /* last ABS value sent */
    int button;   /* last BTN_TL2/BTN_TR2 state sent */
} trigger_t;

/* Maps a raw hall reading to 0..TRIG_MAX and updates the digital state with
 * hysteresis, so sensor noise around the threshold cannot chatter the button. */
static void trigger_update(trigger_t *t, int raw, int *value, int *button) {
    int dev = raw - t->rest;
    if (t->dir == 0) {
        if (dev >= TRIG_DIR_LOCK) t->dir = 1;
        else if (dev <= -TRIG_DIR_LOCK) t->dir = -1;
    }
    int travel = t->dir ? dev * t->dir : 0;
    if (travel < 0) travel = 0;
    if (travel > t->span) t->span = travel;
    int dead = t->span * TRIG_DEAD_PCT / 100;
    int v = 0;
    if (travel > dead)
        v = (int)(((long)(travel - dead) * TRIG_MAX + (t->span - dead) / 2) / (t->span - dead));
    if (v > TRIG_MAX) v = TRIG_MAX;
    int b = t->button;
    if (!b && v >= TRIG_MAX * TRIG_PRESS_PCT / 100) b = 1;
    else if (b && v < TRIG_MAX * TRIG_RELEASE_PCT / 100) b = 0;
    *value = v;
    *button = b;
}

typedef struct { uint16_t mask; int code; } face_map_t;

static const face_map_t face_map[] = {
    { 1u << 4,  BTN_NORTH   },
    { 1u << 5,  BTN_WEST    },
    { 1u << 6,  BTN_SOUTH   },
    { 1u << 7,  BTN_EAST    },
    { 1u << 10, BTN_SELECT  },
    { 1u << 11, BTN_START   },
    { 1u << 12, BTN_THUMBL  },
    { 1u << 13, BTN_THUMBR  },
    /* Byte 1 bit 6 is the Home button and bit 7 the Back button (the stock
     * RsMapping app's table in librsinput.so: KEY_HOME then KEY_BACK, bits read
     * MSB first per byte). Home goes out as BTN_MODE, the key the rest of GammaOS
     * expects from a pad's Home button (the emulators' in-game menu, the
     * framework's BACK/MODE hold); both used to send KEY_BACK. */
    { 1u << 14, BTN_MODE    },
    { 1u << 15, KEY_BACK    },
};
static const size_t face_map_count = sizeof(face_map) / sizeof(face_map[0]);
#define FACE_MASK ((uint16_t)0xFCF0)

static int calib_LX = 0, calib_LY = 0, calib_RX = 0, calib_RY = 0;
static int calib_done = 0;
static long cal_sum[6];
static int cal_n = 0;

static ssize_t write_all(int fd, const void *buf, size_t len) {
    const uint8_t *p = buf;
    size_t total = 0;
    while (total < len) {
        ssize_t ret = write(fd, p + total, len - total);
        if (ret < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        total += (size_t)ret;
    }
    return (ssize_t)total;
}

static int send_init_sequences(int sfd) {
    static const uint8_t seq1[] = { 0xA5,0xD3,0x5A,0x3D, 0x00,0x01,0x02,0x00, 0x07,0x01,0x05 };
    static const uint8_t seq2[] = { 0xA5,0xD3,0x5A,0x3D, 0x01,0x01,0x01,0x00, 0x06,0x07 };
    static const uint8_t seq3[] = { 0xA5,0xD3,0x5A,0x3D, 0x02,0x01,0x01,0x00, 0x02,0x00 };
    static const uint8_t seq4[] = { 0xA5,0xD3,0x5A,0x3D, 0x03,0x01,0x0A,0x00, 0x05,0x01,0x00,0x00,
                                    0x00,0x28,0x00,0x00,0x00,0x07,0x23 };
    static const uint8_t seq5[] = { 0xA5,0xD3,0x5A,0x3D, 0x04,0x01,0x01,0x00, 0x06,0x02 };
    static const uint8_t seq6[] = { 0xA5,0xD3,0x5A,0x3D, 0x05,0x01,0x01,0x00, 0x02,0x07 };
    const uint8_t *seqs[] = { seq1, seq2, seq3, seq4, seq5, seq6 };
    const size_t lens[] = { sizeof(seq1), sizeof(seq2), sizeof(seq3),
                            sizeof(seq4), sizeof(seq5), sizeof(seq6) };
    for (int i = 0; i < 6; i++) {
        if (write_all(sfd, seqs[i], lens[i]) < 0) return -1;
        usleep(100000);
    }
    return 0;
}

static int open_serial(const char *path) {
    int fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) { perror("open serial"); return -1; }
    struct termios t;
    if (tcgetattr(fd, &t) < 0) { perror("tcgetattr"); close(fd); return -1; }
    t.c_iflag &= ~(INPCK | ISTRIP | IXON | IXOFF | BRKINT | ICRNL | IGNCR | IGNBRK);
    t.c_oflag &= ~OPOST;
    t.c_cflag &= ~(CSIZE | PARENB | CRTSCTS);
    t.c_cflag |= CS8 | CLOCAL | CREAD;
    t.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    cfsetispeed(&t, B115200);
    cfsetospeed(&t, B115200);
    t.c_cc[VMIN] = 1;
    t.c_cc[VTIME] = 0;
    if (tcsetattr(fd, TCSANOW, &t) < 0) { perror("tcsetattr"); close(fd); return -1; }
    int flags = fcntl(fd, F_GETFL);
    fcntl(fd, F_SETFL, flags & ~O_NONBLOCK);
    return fd;
}

static void set_abs(struct uinput_user_dev *u, int code, int lo, int hi, int fuzz, int flat) {
    u->absmin[code] = lo;
    u->absmax[code] = hi;
    u->absfuzz[code] = fuzz;
    u->absflat[code] = flat;
}

static int uinput_create(const char *devname) {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) { perror("open /dev/uinput"); return -1; }
#define UI_CHECK(x) do { if ((x) < 0) { perror(#x); close(fd); return -1; } } while (0)
    UI_CHECK(ioctl(fd, UI_SET_EVBIT, EV_KEY));
    for (size_t i = 0; i < face_map_count; i++)
        UI_CHECK(ioctl(fd, UI_SET_KEYBIT, face_map[i].code));
    UI_CHECK(ioctl(fd, UI_SET_KEYBIT, BTN_TL));
    UI_CHECK(ioctl(fd, UI_SET_KEYBIT, BTN_TR));
    UI_CHECK(ioctl(fd, UI_SET_KEYBIT, BTN_TL2));
    UI_CHECK(ioctl(fd, UI_SET_KEYBIT, BTN_TR2));
    UI_CHECK(ioctl(fd, UI_SET_EVBIT, EV_ABS));
    UI_CHECK(ioctl(fd, UI_SET_ABSBIT, ABS_HAT0X));
    UI_CHECK(ioctl(fd, UI_SET_ABSBIT, ABS_HAT0Y));
    UI_CHECK(ioctl(fd, UI_SET_ABSBIT, ABS_X));
    UI_CHECK(ioctl(fd, UI_SET_ABSBIT, ABS_Y));
    UI_CHECK(ioctl(fd, UI_SET_ABSBIT, ABS_Z));
    UI_CHECK(ioctl(fd, UI_SET_ABSBIT, ABS_RZ));
    UI_CHECK(ioctl(fd, UI_SET_ABSBIT, ABS_BRAKE));
    UI_CHECK(ioctl(fd, UI_SET_ABSBIT, ABS_GAS));

    struct uinput_user_dev uidev;
    memset(&uidev, 0, sizeof(uidev));
    snprintf(uidev.name, UINPUT_MAX_NAME_SIZE, "%s", devname);
    uidev.id.bustype = BUS_VIRTUAL;
    uidev.id.vendor  = 0x0001;
    uidev.id.product = 0x0001;
    uidev.id.version = 2;
    set_abs(&uidev, ABS_HAT0X, -1, 1, 0, 0);
    set_abs(&uidev, ABS_HAT0Y, -1, 1, 0, 0);
    set_abs(&uidev, ABS_X,  -STICK_CLIP, STICK_CLIP, STICK_FUZZ, STICK_FLAT);
    set_abs(&uidev, ABS_Y,  -STICK_CLIP, STICK_CLIP, STICK_FUZZ, STICK_FLAT);
    set_abs(&uidev, ABS_Z,  -STICK_CLIP, STICK_CLIP, STICK_FUZZ, STICK_FLAT);
    set_abs(&uidev, ABS_RZ, -STICK_CLIP, STICK_CLIP, STICK_FUZZ, STICK_FLAT);
    set_abs(&uidev, ABS_BRAKE, 0, TRIG_MAX, 0, 0);
    set_abs(&uidev, ABS_GAS,   0, TRIG_MAX, 0, 0);
    UI_CHECK(write_all(fd, &uidev, sizeof(uidev)));
    UI_CHECK(ioctl(fd, UI_DEV_CREATE));
#undef UI_CHECK
    return fd;
}

static uint64_t now_us_monotonic(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000ULL + (uint64_t)ts.tv_nsec / 1000ULL;
}

static int clip_stick(int v) {
    if (v > STICK_CLIP) return STICK_CLIP;
    if (v < -STICK_CLIP) return -STICK_CLIP;
    return v;
}

int main(int argc, char *argv[]) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "Usage: %s \"Retroid Pocket Controller\" [debug]\n", argv[0]);
        return EXIT_FAILURE;
    }
    int debug = (argc == 3 && strcmp(argv[2], "debug") == 0);
    int ufd = uinput_create(argv[1]);
    if (ufd < 0) return EXIT_FAILURE;
    printf("[INFO] Virtual gamepad \"%s\" created (uinput_fd=%d)\n", argv[1], ufd);

    int sfd = -1;
    for (int tries = 0; tries < 50 && sfd < 0; tries++) {
        sfd = open_serial(SERIAL_PATH);
        if (sfd < 0) usleep(200000);
    }
    if (sfd < 0) return EXIT_FAILURE;
    printf("[INFO] Opened MCU serial %s (fd=%d)\n", SERIAL_PATH, sfd);

    if (send_init_sequences(sfd) < 0) {
        fprintf(stderr, "[ERROR] send_init_sequences failed\n");
        close(sfd);
        return EXIT_FAILURE;
    }
    printf("[INFO] Sent init sequences, waiting for incoming packets...\n");

    uint8_t buf[1024];
    size_t buf_len = 0;
    uint64_t last_valid_us = now_us_monotonic();

    uint16_t prev_buttons = 0;
    int prev_hatX = 0, prev_hatY = 0;
    int prev_L1 = 0, prev_R1 = 0, prev_L2 = 0, prev_R2 = 0;
    int prev_L2a = 0, prev_R2a = 0;
    trigger_t trig_L2 = { .span = TRIG_SPAN_MIN }, trig_R2 = { .span = TRIG_SPAN_MIN };
    int prev_LX = 0, prev_LY = 0, prev_RX = 0, prev_RY = 0;

    while (1) {
        uint64_t now_us = now_us_monotonic();
        if (now_us - last_valid_us > 1000000ULL) {
            send_init_sequences(sfd);
            last_valid_us = now_us_monotonic();
            buf_len = 0;
        }

        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(sfd, &rfds);
        struct timeval tmo = { .tv_sec = 1, .tv_usec = 0 };
        int sr = select(sfd + 1, &rfds, NULL, NULL, &tmo);
        if (sr < 0) {
            if (errno == EINTR) continue;
            perror("select");
            break;
        }
        if (sr == 0) continue;

        /* Plain read: the msm geni serial driver logs every FIONREAD ioctl
         * to the kernel log, so size the read by the buffer space instead. */
        if (buf_len >= sizeof(buf)) buf_len = 0;
        ssize_t r = read(sfd, buf + buf_len, sizeof(buf) - buf_len);
        if (r < 0) {
            if (errno == EINTR || errno == EAGAIN) continue;
            perror("read");
            break;
        }
        if (r == 0) continue;
        buf_len += (size_t)r;

        size_t offset = 0;
        while (buf_len - offset >= 8) {
            if (buf[offset] != 0xA5 || buf[offset+1] != 0xD3 ||
                buf[offset+2] != 0x5A || buf[offset+3] != 0x3D) {
                offset++;
                continue;
            }
            uint8_t cmd = buf[offset+5];
            uint16_t data_len = (uint16_t)(buf[offset+6] | (buf[offset+7] << 8));
            size_t packet_len = 8 + data_len + 1;
            if (packet_len > sizeof(buf)) { offset++; continue; }
            if (buf_len - offset < packet_len) break;

            uint8_t cs = buf[offset+4];
            for (size_t i = offset+5; i < offset+packet_len-1; i++) cs ^= buf[i];
            if (cs != buf[offset+packet_len-1]) { offset++; continue; }

            if (cmd == 0x02 && data_len >= 14) {
                const uint8_t *d = buf + offset + 8;
                last_valid_us = now_us_monotonic();
                uint16_t buttons = (uint16_t)(d[0] | (d[1] << 8));
                int16_t raw_LX = (int16_t)(d[6]  | (d[7]  << 8));
                int16_t raw_LY = (int16_t)(d[8]  | (d[9]  << 8));
                int16_t raw_RX = (int16_t)(d[10] | (d[11] << 8));
                int16_t raw_RY = (int16_t)(d[12] | (d[13] << 8));
                int raw_L2 = d[2] | (d[3] << 8);
                int raw_R2 = d[4] | (d[5] << 8);

                if (!calib_done) {
                    cal_sum[0] += raw_LX; cal_sum[1] += raw_LY;
                    cal_sum[2] += raw_RX; cal_sum[3] += raw_RY;
                    cal_sum[4] += raw_L2; cal_sum[5] += raw_R2;
                    if (++cal_n >= STICK_CAL_FRAMES) {
                        calib_LX = (int)(cal_sum[0] / cal_n);
                        calib_LY = (int)(cal_sum[1] / cal_n);
                        calib_RX = (int)(cal_sum[2] / cal_n);
                        calib_RY = (int)(cal_sum[3] / cal_n);
                        trig_L2.rest = (int)(cal_sum[4] / cal_n);
                        trig_R2.rest = (int)(cal_sum[5] / cal_n);
                        calib_done = 1;
                        printf("[INFO] Stick centre LX=%d LY=%d RX=%d RY=%d, trigger rest L2=%d R2=%d\n",
                               calib_LX, calib_LY, calib_RX, calib_RY, trig_L2.rest, trig_R2.rest);
                    }
                }
                if (debug) {
                    printf("btn=%04x L2=%d R2=%d LX=%d LY=%d RX=%d RY=%d\n",
                           buttons, raw_L2, raw_R2, raw_LX, raw_LY, raw_RX, raw_RY);
                    fflush(stdout);
                }
                int LX = calib_done ? clip_stick(-(raw_LX - calib_LX)) : 0;
                int LY = calib_done ? clip_stick(-(raw_LY - calib_LY)) : 0;
                int RX = calib_done ? clip_stick(-(raw_RX - calib_RX)) : 0;
                int RY = calib_done ? clip_stick(-(raw_RY - calib_RY)) : 0;

                struct timeval tv;
                gettimeofday(&tv, NULL);
                struct input_event evs[32];
                int n = 0;
#define EMIT(T, C, V) do { evs[n].time = tv; evs[n].type = (T); evs[n].code = (C); evs[n].value = (V); n++; } while (0)

                int hatX = ((buttons & (1u<<3)) ? 1 : 0) - ((buttons & (1u<<2)) ? 1 : 0);
                int hatY = ((buttons & (1u<<1)) ? 1 : 0) - ((buttons & (1u<<0)) ? 1 : 0);
                if (hatX != prev_hatX) EMIT(EV_ABS, ABS_HAT0X, hatX);
                if (hatY != prev_hatY) EMIT(EV_ABS, ABS_HAT0Y, hatY);

                uint16_t changed_face = (uint16_t)((buttons ^ prev_buttons) & FACE_MASK);
                if (changed_face) {
                    for (size_t i = 0; i < face_map_count; i++)
                        if (changed_face & face_map[i].mask)
                            EMIT(EV_KEY, face_map[i].code, (buttons & face_map[i].mask) ? 1 : 0);
                }

                int L1 = (buttons & (1u<<8)) ? 1 : 0;
                int R1 = (buttons & (1u<<9)) ? 1 : 0;
                int L2 = 0, R2 = 0, L2a = 0, R2a = 0;
                if (calib_done) {
                    trigger_update(&trig_L2, raw_L2, &L2a, &L2);
                    trigger_update(&trig_R2, raw_R2, &R2a, &R2);
                    trig_L2.value = L2a; trig_L2.button = L2;
                    trig_R2.value = R2a; trig_R2.button = R2;
                }
                if (L2a != prev_L2a) EMIT(EV_ABS, ABS_BRAKE, L2a);
                if (R2a != prev_R2a) EMIT(EV_ABS, ABS_GAS,   R2a);
                if (L1 != prev_L1) EMIT(EV_KEY, BTN_TL,  L1);
                if (R1 != prev_R1) EMIT(EV_KEY, BTN_TR,  R1);
                if (L2 != prev_L2) EMIT(EV_KEY, BTN_TL2, L2);
                if (R2 != prev_R2) EMIT(EV_KEY, BTN_TR2, R2);

                if (LX != prev_LX) EMIT(EV_ABS, ABS_X,  LX);
                if (LY != prev_LY) EMIT(EV_ABS, ABS_Y,  LY);
                if (RX != prev_RX) EMIT(EV_ABS, ABS_Z,  RX);
                if (RY != prev_RY) EMIT(EV_ABS, ABS_RZ, RY);

                if (n > 0) {
                    EMIT(EV_SYN, SYN_REPORT, 0);
                    write_all(ufd, evs, (size_t)n * sizeof(evs[0]));
                }
#undef EMIT
                prev_buttons = buttons;
                prev_hatX = hatX; prev_hatY = hatY;
                prev_L1 = L1; prev_R1 = R1; prev_L2 = L2; prev_R2 = R2;
                prev_L2a = L2a; prev_R2a = R2a;
                prev_LX = LX; prev_LY = LY; prev_RX = RX; prev_RY = RY;
            }
            offset += packet_len;
        }
        if (offset > 0) {
            memmove(buf, buf + offset, buf_len - offset);
            buf_len -= offset;
        }
    }
    close(sfd);
    ioctl(ufd, UI_DEV_DESTROY);
    close(ufd);
    return EXIT_SUCCESS;
}

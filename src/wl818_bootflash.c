// wl818_bootflash - run the WL818S bridge firmware check at post-fs and reboot
// right there when this boot flashed the bridge.
//
// The sec_bl_uart module checks (and if the date differs, flashes) the bridge
// firmware on the DP power-on event, and the display driver powers the DP on the
// FIRST open of /dev/dri/card0 (dp_display_post_open). Nano opens the node at
// late-fs on a normal boot, but on a first boot after a factory reset or a fresh
// install the rest of the boot is long and the old reboot service only ran at
// "on boot", after all of that. This tool runs synchronously (exec_start) from
// post-fs, right after the firmware choice is made and BEFORE late-fs mounts
// /data: it opens the DRM node itself (which powers the DP and starts fw_check),
// watches the kernel log and, when a flash succeeded, reboots while nothing of
// /data has been touched yet (a reboot during the first boot's data setup left
// the device in recovery with "Can't load Android system"). On a normal boot it
// returns as soon as the module reports the check complete without an upgrade,
// bounded by a few seconds, so boot time is unaffected. It never loops: after a
// successful flash the next boot's dates match and nothing is flashed.
//
// The reboot is taken on a confirmed upload ("fw_upgrade: SUCCESS": every packet
// acknowledged) even when the date readback right after it times out: on this
// bridge the readback fails after a flash while the MCU restarts (rc=-110), the
// next boot then reads the new date fine, and not rebooting leaves the DP
// erroring for the whole session. A flash that did not upload does not reboot
// (Volume-Up stock path). Reboots are counted in persist (reset by any boot whose
// check completes without an upgrade) and stop after kMaxRebootsInARow, so a
// bridge that never takes the firmware cannot loop the device. No DRM master is
// taken, so nano's own open is not disturbed.
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/system_properties.h>
#include <time.h>
#include <unistd.h>

#define TAG "wl818_bootflash"
#define DRM_NODE "/dev/dri/card0"
#define DP_CONNECTOR "/sys/class/drm/card0-DP-1" // the DP display is registered: its first open powers it
#define DRM_WAIT_MS 20000    // the node and the DP connector appear a few seconds into boot
#define CHECK_WAIT_MS 8000   // no upgrade: DP on, banner read and the date compare take ~1-2 s
#define UPGRADE_WAIT_MS 120000 // an upgrade adds ~10 s; generous bound
#define REBOOT_COUNT_FILE "/mnt/vendor/persist/wl818/flash_reboots"
#define kMaxRebootsInARow 2

static void klog(const char* msg) {
    int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    if (fd < 0) return;
    char buf[256];
    int n = snprintf(buf, sizeof(buf), TAG ": %s\n", msg);
    if (n > 0) write(fd, buf, (size_t)n);
    close(fd);
}

static long long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000LL + ts.tv_nsec / 1000000;
}

int main(void) {
    // Open the log first so nothing between the DP power-on and the result can be
    // missed; reading starts at the oldest record still in the buffer.
    int kfd = open("/dev/kmsg", O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (kfd < 0) {
        klog("cannot open /dev/kmsg; giving up");
        return 1;
    }

    // Power the DP on by opening the DRM node (first open triggers it). Keep the
    // fd open until the check is over so the bridge is not powered off under a
    // running flash by a last-close.
    long long t0 = now_ms();
    int dfd = -1;
    while (now_ms() - t0 < DRM_WAIT_MS) {
        // the DP display arms its first-open trigger at probe; an open before that does nothing
        if (access(DP_CONNECTOR, F_OK) == 0) {
            dfd = open(DRM_NODE, O_RDWR | O_CLOEXEC);
            if (dfd >= 0) break;
        }
        usleep(50000);
    }
    if (dfd >= 0) {
        char m[96];
        snprintf(m, sizeof(m), "opened %s after %lld ms (DP power-on requested)", DRM_NODE, now_ms() - t0);
        klog(m);
    } else {
        klog(DRM_NODE " did not appear; watching the log anyway");
    }

    int success = 0, readback = 0, complete = 0, started = 0;
    long long t1 = now_ms();
    char line[2048];
    while (!complete && now_ms() - t1 < (started ? UPGRADE_WAIT_MS : CHECK_WAIT_MS)) {
        struct pollfd p = {.fd = kfd, .events = POLLIN};
        int r = poll(&p, 1, 500);
        if (r <= 0) continue;
        ssize_t n = read(kfd, line, sizeof(line) - 1);
        if (n < 0) {
            if (errno == EPIPE) continue; // records were overwritten; keep reading
            if (errno == EAGAIN) continue;
            break;
        }
        line[n] = 0;
        if (!strstr(line, "sec-bl-uart")) continue;
        if (strstr(line, "fw_check: starting firmware upgrade")) started = 1;
        if (strstr(line, "fw_upgrade: SUCCESS")) success = 1;
        if (strstr(line, "fw_check: MCU date readback after upgrade=")) readback = 1;
        if (strstr(line, "fw_check: complete")) complete = 1;
    }

    char m[200];
    int reboots = 0;
    {
        FILE* f = fopen(REBOOT_COUNT_FILE, "r");
        if (f) {
            if (fscanf(f, "%d", &reboots) != 1) reboots = 0;
            fclose(f);
        }
    }
    if (complete && success && reboots < kMaxRebootsInARow) {
        FILE* f = fopen(REBOOT_COUNT_FILE, "w");
        if (f) {
            fprintf(f, "%d\n", reboots + 1);
            fclose(f);
        }
        snprintf(m, sizeof(m), "bridge firmware uploaded this boot (readback %s, %lld ms after start); rebooting for a clean DP bring-up (%d of %d)",
                 readback ? "ok" : "timed out", now_ms() - t0, reboots + 1, kMaxRebootsInARow);
        klog(m);
        sync();
        if (__system_property_set("sys.powerctl", "reboot") != 0) {
            klog("sys.powerctl set failed");
        }
        // init carries out the reboot once this exec returns; the DRM node is closed by exit.
    } else if (complete && success) {
        snprintf(m, sizeof(m), "bridge firmware uploaded again but %d reboots in a row did not settle it; not rebooting (Volume-Up at boot selects the stock firmware)", reboots);
        klog(m);
    } else if (!complete) {
        snprintf(m, sizeof(m), "no fw_check result within %d s (upgrade started: %d); nothing to do",
                 (started ? UPGRADE_WAIT_MS : CHECK_WAIT_MS) / 1000, started);
        klog(m);
    } else {
        if (!started && reboots != 0) {
            // the dates match again: the chain of flash + reboot is over
            FILE* f = fopen(REBOOT_COUNT_FILE, "w");
            if (f) { fputs("0\n", f); fclose(f); }
        }
        snprintf(m, sizeof(m), "no bridge flash this boot (upgrade started: %d, success: %d, readback: %d); nothing to do",
                 started, success, readback);
        klog(m);
    }
    if (dfd >= 0) close(dfd);
    close(kfd);
    return 0;
}

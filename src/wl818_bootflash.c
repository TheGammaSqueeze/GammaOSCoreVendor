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
#include <sys/ioctl.h>
#include <sys/types.h>
#include <drm/drm.h>
#include <time.h>
#include <unistd.h>

#define TAG "wl818_bootflash"
#define DRM_NODE "/dev/dri/card0"
#define DP_CONNECTOR "/sys/class/drm/card0-DP-1" // the DP display is registered: its first open powers it
#define DRM_WAIT_MS 20000    // the node and the DP connector appear a few seconds into boot
#define CHECK_WAIT_MS 8000   // no upgrade: DP on, banner read and the date compare take ~1-2 s
#define UPGRADE_WAIT_MS 120000 // an upgrade adds ~10 s; generous bound (+16 s for the nano recovery try)
#define HOLD_WAIT_MS 120000  // the DRM handle stays open until nano has the node (bounded)
#define REBOOT_COUNT_FILE "/mnt/vendor/persist/wl818/flash_reboots"
#define kMaxRebootsInARow 10
#define ALT_FLAG_FILE "/mnt/vendor/persist/wl818/alt"   // read by wl818_select.sh: 1 = the other base image

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
        // the first opener of a DRM node is its master until it drops that: give it up at
        // once, so nano's SET_MASTER succeeds while this handle (and the hold below) stays open
        if (ioctl(dfd, DRM_IOCTL_DROP_MASTER, 0) != 0) klog("DROP_MASTER on the DRM node failed (nano may not get master while the hold lasts)");
        char m[96];
        snprintf(m, sizeof(m), "opened %s after %lld ms (DP power-on requested, master dropped)", DRM_NODE, now_ms() - t0);
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
    // persist.gammaos.wl818.noreboot=1: log what would happen and never reboot (bench use)
    char noreboot[PROP_VALUE_MAX] = {};
    __system_property_get("persist.gammaos.wl818.noreboot", noreboot);
    const int bench = noreboot[0] == '1';
    int reboots = 0;
    {
        FILE* f = fopen(REBOOT_COUNT_FILE, "r");
        if (f) {
            if (fscanf(f, "%d", &reboots) != 1) reboots = 0;
            fclose(f);
        }
    }
    // Let the MCU finish with the image before any reboot. The upload is acknowledged packet
    // by packet, but the MCU then commits it and restarts, and the module's 3 s readback
    // comes too early (rc=-110). A reboot right there power-cycles the bridge mid-commit and
    // the next boots find a silent MCU and upload all over again. Poll the running date and
    // go on as soon as the MCU answers, or after the window.
    // Let the MCU finish with the image before any reboot: poll its running date for up to
    // 45 s after the upload and go on as soon as it answers.
    int mcuAnswered = 0;
    if (complete && success) {
        char d[64] = {};
        long long ts = now_ms();
        while (now_ms() - ts < 45000) {
            FILE* f = fopen("/sys/class/wl818_reset/mcu_date", "r");
            if (f) { if (!fgets(d, sizeof(d), f)) d[0] = 0; fclose(f); }
            size_t n = strlen(d);
            while (n && (d[n - 1] == '\n' || d[n - 1] == ' ')) d[--n] = 0;
            if (n == 8 && d[0] == '2') break;
            d[0] = 0;
            usleep(500000);
        }
        if (d[0]) { mcuAnswered = 1; snprintf(m, sizeof(m), "%lld ms after the upload the MCU answers with its date (%s)", now_ms() - ts, d); }
        else snprintf(m, sizeof(m), "%lld ms after the upload the MCU still gives no date", now_ms() - ts);
        klog(m);
    }
    // Two builds of the custom firmware ship, one per MCU image layout (20260917 and
    // 20260912 base); an MCU boot-loops on the wrong one and never answers. When an upload
    // leaves the MCU silent, flip to the other base for the next boot so the two rotate
    // until one takes; a boot that answers keeps whatever is selected.
    if (complete && success && !mcuAnswered) {
        int alt = 0;
        FILE* f = fopen(ALT_FLAG_FILE, "r");
        if (f) { if (fscanf(f, "%d", &alt) != 1) alt = 0; fclose(f); }
        f = fopen(ALT_FLAG_FILE, "w");
        if (f) { fprintf(f, "%d\n", alt ? 0 : 1); fclose(f); }
        sync();
        snprintf(m, sizeof(m), "MCU silent after this upload; the next boot uses the %s base image", alt ? "20260917" : "20260912");
        klog(m);
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
        if (bench) klog("noreboot set: not rebooting");
        else if (__system_property_set("sys.powerctl", "reboot") != 0) {
            klog("sys.powerctl set failed");
        }
        // init carries out the reboot once this exec returns; the DRM node is closed by exit.
    } else if (complete && success) {
        snprintf(m, sizeof(m), "bridge firmware uploaded again but %d reboots in a row did not settle it; not rebooting", reboots);
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
    // Never be the last close of the DRM node. This tool is the first opener of card0 on a
    // boot; if it also closes it before nano has the node open, the kernel's last-close path
    // (sde_kms_lastclose) hands the pipes back to its boot splash client and the DSI panel is
    // left in the splash handoff state: the home still flips, but a blank frame and a
    // backlight 0 at sleep no longer reach the top panel (it stays lit on the last frame
    // until SurfaceFlinger power-cycles it). A child holds the handle in its own session
    // (init kills the service's process group when this exec returns) until nano reports
    // the DRM home up, bounded, then lets go: nano's open keeps the node from closing.
    if (dfd >= 0) {
        // the parent only returns once the child has left the session and the cgroup: init
        // kills both within milliseconds of this exec returning
        int hs[2] = {-1, -1};
        if (pipe(hs) != 0) hs[0] = hs[1] = -1;
        pid_t pid = fork();
        if (pid == 0) {
            if (hs[0] >= 0) close(hs[0]);
            // own session, and out of the service's cgroup: init kills every task left in
            // it when this exec returns (the hold died at 10 s and the close went ahead)
            setsid();
            close(kfd);
            {
                int cg = open("/sys/fs/cgroup/cgroup.procs", O_WRONLY | O_CLOEXEC);
                if (cg >= 0) {
                    char pb[32];
                    int n = snprintf(pb, sizeof(pb), "%d\n", (int)getpid());
                    if (write(cg, pb, (size_t)n) != n) klog("could not leave the service cgroup; the hold may be cut short");
                    close(cg);
                } else {
                    klog("no cgroup.procs to leave the service cgroup; the hold may be cut short");
                }
            }
            if (hs[1] >= 0) { (void)!write(hs[1], "d", 1); close(hs[1]); }
            char v[PROP_VALUE_MAX] = {};
            long long th = now_ms();
            while (now_ms() - th < HOLD_WAIT_MS) {
                v[0] = 0;
                __system_property_get("sys.gammaos.nano.drm_active", v);
                if (v[0] == '1') break;
                usleep(200000);
            }
            snprintf(m, sizeof(m), "DRM node released %lld ms later (nano drm_active=%s)", now_ms() - th, v[0] ? v : "unset");
            klog(m);
            close(dfd);
            _exit(0);
        }
        if (pid < 0) klog("fork for the DRM hold failed; closing the node now");
        if (hs[1] >= 0) close(hs[1]);
        if (hs[0] >= 0) {
            if (pid > 0) {
                char b;
                struct pollfd hp = {.fd = hs[0], .events = POLLIN};
                if (poll(&hp, 1, 2000) > 0) (void)!read(hs[0], &b, 1);
                else klog("the DRM hold did not report in; it may be cut short");
            }
            close(hs[0]);
        }
        // the parent's copy closes with the exit; the child's keeps the node open
    }
    close(kfd);
    return 0;
}

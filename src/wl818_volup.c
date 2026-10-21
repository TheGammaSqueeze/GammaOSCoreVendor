// wl818_volup - exit 0 if Volume-Up is being held right now, 1 otherwise.
//
// Scans /dev/input/event* and reports the current (held) state of KEY_VOLUMEUP
// via EVIOCGKEY, which reflects the live hardware key state (not an event
// stream), so it works when read once early at boot. Used by wl818_select.sh to
// toggle the stock/custom bridge-firmware choice when the user holds Volume-Up
// during boot.
#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#ifndef KEY_VOLUMEUP
#define KEY_VOLUMEUP 115
#endif

static int held_on(const char *path) {
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return 0;
    unsigned long bits[(KEY_MAX + 1 + 8 * sizeof(long) - 1) / (8 * sizeof(long))];
    memset(bits, 0, sizeof(bits));
    int held = 0;
    if (ioctl(fd, EVIOCGKEY(sizeof(bits)), bits) >= 0) {
        if (bits[KEY_VOLUMEUP / (8 * sizeof(long))] &
            (1UL << (KEY_VOLUMEUP % (8 * sizeof(long)))))
            held = 1;
    }
    close(fd);
    return held;
}

int main(void) {
    DIR *d = opendir("/dev/input");
    if (!d) return 1;
    struct dirent *e;
    int held = 0;
    while ((e = readdir(d))) {
        if (strncmp(e->d_name, "event", 5) != 0) continue;
        char path[64];
        snprintf(path, sizeof(path), "/dev/input/%s", e->d_name);
        if (held_on(path)) { held = 1; break; }
    }
    closedir(d);
    return held ? 0 : 1;
}

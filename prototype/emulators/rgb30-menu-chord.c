#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <glob.h>
#include <linux/input.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/prctl.h>
#include <unistd.h>

static volatile sig_atomic_t running = 1;

static void stop(int signal_number)
{
    (void)signal_number;
    running = 0;
}

static bool is_rgb30(void)
{
    char model[64] = {0};
    FILE *file = fopen("/proc/device-tree/model", "rb");
    if (!file)
        return false;
    size_t length = fread(model, 1, sizeof(model) - 1, file);
    fclose(file);
    return length > 0 && strcmp(model, "Powkiddy RGB30") == 0;
}

static int open_joypad(void)
{
    glob_t paths = {0};
    int result = -1;
    if (glob("/dev/input/event[0-9]*", 0, NULL, &paths) == 0) {
        for (size_t index = 0; index < paths.gl_pathc; index++) {
            char name[64] = {0};
            int fd = open(paths.gl_pathv[index], O_RDWR | O_CLOEXEC | O_NONBLOCK);
            if (fd < 0)
                continue;
            if (ioctl(fd, EVIOCGNAME(sizeof(name)), name) >= 0 &&
                strcmp(name, "retrogame_joypad") == 0) {
                result = fd;
                break;
            }
            close(fd);
        }
    }
    globfree(&paths);
    return result;
}

static bool set_menu_key(int fd, bool down)
{
    struct input_event events[] = {
        {.type = EV_KEY, .code = BTN_MODE, .value = down},
        {.type = EV_SYN, .code = SYN_REPORT},
    };
    return write(fd, events, sizeof(events)) == (ssize_t)sizeof(events);
}

int main(int argc, char **argv)
{
    if (!is_rgb30())
        return 0;
    if (argc != 3)
        return 2;
    char *end;
    long parent = strtol(argv[1], &end, 10);
    if (*end || parent <= 1)
        return 2;
    unsigned int menu_partner;
    if (strcmp(argv[2], "retroarch") == 0)
        menu_partner = BTN_SOUTH; /* The RGB30's physical B. */
    else if (strcmp(argv[2], "standalone") == 0)
        menu_partner = BTN_START;
    else
        return 2;

    const struct sigaction action = {.sa_handler = stop};
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGHUP, &action, NULL);
    if (prctl(PR_SET_PDEATHSIG, SIGTERM, 0, 0, 0) < 0 ||
        getppid() != parent)
        return 1;

    int fd = open_joypad();
    if (fd < 0) {
        perror("plumOS RGB30 menu chord: joypad unavailable");
        return 1;
    }

    bool select_down = false, partner_down = false, menu_down = false;
    bool dropped = false;
    struct pollfd input = {.fd = fd, .events = POLLIN};
    while (running) {
        int ready = poll(&input, 1, 250);
        if (ready == 0 || (ready < 0 && errno == EINTR))
            continue;
        if (ready < 0 || !(input.revents & POLLIN))
            break;
        struct input_event event;
        ssize_t count = read(fd, &event, sizeof(event));
        if (count < 0 && (errno == EINTR || errno == EAGAIN))
            continue;
        if (count != (ssize_t)sizeof(event))
            break;
        if (event.type == EV_SYN && event.code == SYN_DROPPED) {
            /* Discard this chord and resume on the next complete packet. */
            select_down = partner_down = false;
            dropped = true;
        } else if (dropped) {
            if (event.type == EV_SYN && event.code == SYN_REPORT)
                dropped = false;
            continue;
        } else if (event.type != EV_KEY || event.value > 1) {
            continue;
        } else if (event.code == BTN_SELECT) {
            select_down = event.value == 1;
        } else if (event.code == menu_partner) {
            partner_down = event.value == 1;
        } else {
            continue;
        }
        bool chord = select_down && partner_down;
        if (chord != menu_down && set_menu_key(fd, chord))
            menu_down = chord;
    }
    if (menu_down)
        set_menu_key(fd, false);
    close(fd);
    return 0;
}

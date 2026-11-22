#include <stdio.h>
#include <string.h>
#include <sys/reboot.h>

int main(int argc, char **argv)
{
    if (argc != 2) return 2;
    int command;
    if (strcmp(argv[1], "reboot") == 0) command = RB_AUTOBOOT;
    else if (strcmp(argv[1], "poweroff") == 0) command = RB_POWER_OFF;
    else return 2;
    if (reboot(command) == 0) return 0;
    perror("reboot");
    return 1;
}

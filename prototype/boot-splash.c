#include <fcntl.h>
#include <linux/fb.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

enum { width = 640, height = 480, pixel_bytes = 4, row_bytes = width * pixel_bytes };
static unsigned char image[height][row_bytes];

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;

    FILE *source = fopen(argv[1], "rb");
    if (!source)
        return 1;
    int complete = fread(image, 1, sizeof(image), source) == sizeof(image) &&
                   fgetc(source) == EOF && !ferror(source);
    fclose(source);
    if (!complete)
        return 1;

    int fb = open("/dev/fb0", O_RDWR | O_CLOEXEC);
    if (fb < 0)
        return 1;

    struct fb_fix_screeninfo fix;
    struct fb_var_screeninfo var;
    if (ioctl(fb, FBIOGET_FSCREENINFO, &fix) != 0 ||
        ioctl(fb, FBIOGET_VSCREENINFO, &var) != 0 ||
        fix.type != FB_TYPE_PACKED_PIXELS || fix.visual != FB_VISUAL_TRUECOLOR ||
        var.bits_per_pixel != 32 || var.xres != width || var.yres != height ||
        var.red.offset != 16 || var.green.offset != 8 || var.blue.offset != 0 ||
        var.red.length != 8 || var.green.length != 8 || var.blue.length != 8) {
        close(fb);
        return 1;
    }

    uint64_t x = (uint64_t)var.xoffset * pixel_bytes;
    uint64_t start = (uint64_t)var.yoffset * fix.line_length + x;
    uint64_t end = start + (uint64_t)(height - 1) * fix.line_length + row_bytes;
    if (x + row_bytes > fix.line_length || end > fix.smem_len) {
        close(fb);
        return 1;
    }

    unsigned char *screen = mmap(NULL, fix.smem_len, PROT_WRITE, MAP_SHARED, fb, 0);
    if (screen == MAP_FAILED) {
        close(fb);
        return 1;
    }
    for (unsigned int row = 0; row < height; row++)
        memcpy(screen + start + row * (uint64_t)fix.line_length, image[row], row_bytes);
    munmap(screen, fix.smem_len);
    close(fb);
    return 0;
}

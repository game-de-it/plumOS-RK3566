#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

enum { width = 640, height = 480, pixel_bytes = 4, row_bytes = width * pixel_bytes };
static unsigned char image[height][row_bytes];

static int write_pixels(int fb, const unsigned char *pixels, size_t bytes,
                        uint64_t offset)
{
    while (bytes) {
        ssize_t written = pwrite(fb, pixels, bytes, (off_t)offset);
        if (written < 0 && errno == EINTR)
            continue;
        if (written <= 0)
            return 1;
        pixels += written;
        bytes -= (size_t)written;
        offset += (uint64_t)written;
    }
    return 0;
}

static int clear_framebuffer(int fb, uint64_t bytes)
{
    static const unsigned char black[4096];
    uint64_t offset = 0;
    while (offset < bytes) {
        uint64_t remaining = bytes - offset;
        size_t chunk = remaining < sizeof(black) ? (size_t)remaining : sizeof(black);
        if (write_pixels(fb, black, chunk, offset))
            return 1;
        offset += chunk;
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;

    bool clear = strcmp(argv[1], "--clear") == 0;
    if (!clear) {
        FILE *source = fopen(argv[1], "rb");
        if (!source)
            return 1;
        bool complete = fread(image, 1, sizeof(image), source) == sizeof(image) &&
                        fgetc(source) == EOF && !ferror(source);
        fclose(source);
        if (!complete)
            return 1;
    }

    int fb = open("/dev/fb0", O_RDWR | O_CLOEXEC);
    if (fb < 0)
        return 1;

    struct fb_fix_screeninfo fix;
    struct fb_var_screeninfo var;
    if (ioctl(fb, FBIOGET_FSCREENINFO, &fix) != 0 ||
        ioctl(fb, FBIOGET_VSCREENINFO, &var) != 0 ||
        fix.type != FB_TYPE_PACKED_PIXELS || fix.visual != FB_VISUAL_TRUECOLOR ||
        var.bits_per_pixel != 32 || !var.xres || !var.yres ||
        var.red.offset != 16 || var.green.offset != 8 || var.blue.offset != 0 ||
        var.red.length != 8 || var.green.length != 8 || var.blue.length != 8) {
        close(fb);
        return 1;
    }

    uint64_t x = (uint64_t)var.xoffset * pixel_bytes;
    uint64_t start = (uint64_t)var.yoffset * fix.line_length + x;
    uint64_t visible_row_bytes = (uint64_t)var.xres * pixel_bytes;
    uint64_t end = start + ((uint64_t)var.yres - 1) * fix.line_length + visible_row_bytes;
    uint64_t virtual_bytes = (uint64_t)var.yres_virtual * fix.line_length;
    if ((uint64_t)var.yoffset + var.yres > var.yres_virtual ||
        x + visible_row_bytes > fix.line_length || end > fix.smem_len ||
        (clear && (virtual_bytes < end || virtual_bytes > fix.smem_len))) {
        close(fb);
        return 1;
    }

    if (clear) {
        /* fbcon can become visible when a DRM client drops master. */
        int result = clear_framebuffer(fb, virtual_bytes);
        close(fb);
        return result;
    }

    unsigned char *scanline = calloc(1, (size_t)visible_row_bytes);
    if (!scanline) {
        close(fb);
        return 1;
    }
    unsigned int draw_width = var.xres;
    unsigned int draw_height = (uint64_t)var.xres * height / width;
    if (draw_height > var.yres) {
        draw_width = (uint64_t)var.yres * width / height;
        draw_height = var.yres;
    }
    if (!draw_width)
        draw_width = 1;
    if (!draw_height)
        draw_height = 1;
    unsigned int left = (var.xres - draw_width) / 2;
    unsigned int top = (var.yres - draw_height) / 2;

    int result = 0;
    for (unsigned int row = 0; row < var.yres; row++) {
        if (row == top + draw_height)
            memset(scanline, 0, (size_t)visible_row_bytes);
        if (row >= top && row - top < draw_height) {
            const unsigned char *src = image[(uint64_t)(row - top) * height / draw_height];
            unsigned char *dst = scanline + (size_t)left * pixel_bytes;
            if (draw_width == width) {
                memcpy(dst, src, row_bytes);
            } else {
                for (unsigned int col = 0; col < draw_width; col++)
                    memcpy(dst + (size_t)col * pixel_bytes,
                           src + (uint64_t)col * width / draw_width * pixel_bytes,
                           pixel_bytes);
            }
        }
        result = write_pixels(fb, scanline, (size_t)visible_row_bytes,
                              start + (uint64_t)row * fix.line_length);
        if (result)
            break;
    }
    free(scanline);
    close(fb);
    if (!result)
        printf("framebuffer: %ux%u XRGB8888\n", var.xres, var.yres);
    return result;
}

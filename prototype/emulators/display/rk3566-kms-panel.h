/* SPDX-License-Identifier: MIT */
#ifndef PLUMOS_RK3566_KMS_PANEL_H
#define PLUMOS_RK3566_KMS_PANEL_H

#include <dlfcn.h>
#include <gbm.h>
#include <stdbool.h>

#include "plumos-rga/RgaApi.h"

struct plumos_gbm_ops {
    struct gbm_bo *(*create)(struct gbm_device *, uint32_t, uint32_t, uint32_t, uint32_t);
    void (*destroy)(struct gbm_bo *);
    int (*get_fd)(struct gbm_bo *);
    uint32_t (*stride)(struct gbm_bo *);
    uint64_t (*modifier)(struct gbm_bo *);
};

struct plumos_panel {
    struct plumos_gbm_ops gbm;
    void *library;
    void (*deinit)(void);
    int (*blit)(rga_info_t *, rga_info_t *, rga_info_t *);
    struct gbm_bo *scanout[2];
    int dma_fd[2];
    unsigned int front;
    uint32_t width, height;
    bool initialized;
    bool submitted;
};

static inline bool plumos_rgb10max3_portrait(bool internal, uint32_t width, uint32_t height)
{
    char model[64] = {0};
    FILE *file;
    if (!internal || !width || width >= height)
        return false;
    file = fopen("/proc/device-tree/model", "rb");
    if (!file)
        return false;
    (void)fread(model, 1, sizeof(model) - 1, file);
    fclose(file);
    return strcmp(model, "Powkiddy RGB10 Max 3") == 0 ||
           strcmp(model, "Powkiddy RGB10MAX3") == 0;
}

static inline bool plumos_panel_linear(const struct plumos_gbm_ops *gbm, struct gbm_bo *bo)
{
    /* Older Mali GBM does not expose modifier information. */
    const uint64_t invalid_modifier = (UINT64_C(1) << 56) - 1;
    uint64_t modifier = gbm->modifier ? gbm->modifier(bo) : invalid_modifier;
    return modifier == 0 || modifier == invalid_modifier;
}

static inline void plumos_panel_close(struct plumos_panel *panel)
{
    if (!panel->library)
        return;
    for (unsigned int i = 0; i < 2; i++) {
        if (panel->dma_fd[i] >= 0)
            close(panel->dma_fd[i]);
        if (panel->scanout[i])
            panel->gbm.destroy(panel->scanout[i]);
    }
    if (panel->initialized)
        panel->deinit();
    dlclose(panel->library);
    memset(panel, 0, sizeof(*panel));
}

static inline bool plumos_panel_open(struct plumos_panel *panel, const struct plumos_gbm_ops *gbm,
                              struct gbm_device *device, uint32_t width, uint32_t height,
                              uint32_t format)
{
    int (*init)(void);
    const char *root = getenv("PLUMOS_ROOT");
    char library_path[4096];
    int length;

    if (!gbm->get_fd)
        return false;
    if (!root || !*root)
        root = "/usr/lib/plumos-353m/frontend";
    length = snprintf(library_path, sizeof(library_path), "%s/lib/rgb10max3/librga.so.2", root);
    if (length < 0 || (size_t)length >= sizeof(library_path))
        return false;
    panel->library = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
    if (!panel->library)
        return false;
    panel->gbm = *gbm;
    panel->width = width;
    panel->height = height;
    panel->dma_fd[0] = panel->dma_fd[1] = -1;
    init = dlsym(panel->library, "c_RkRgaInit");
    panel->deinit = dlsym(panel->library, "c_RkRgaDeInit");
    panel->blit = dlsym(panel->library, "c_RkRgaBlit");
    if (!init || !panel->deinit || !panel->blit || init() != 0)
        goto fail;
    panel->initialized = true;
    for (unsigned int i = 0; i < 2; i++) {
        panel->scanout[i] = gbm->create(device, width, height, format,
                                      GBM_BO_USE_SCANOUT | GBM_BO_USE_RENDERING);
        if (!panel->scanout[i] || !plumos_panel_linear(gbm, panel->scanout[i]))
            goto fail;
        panel->dma_fd[i] = gbm->get_fd(panel->scanout[i]);
        if (panel->dma_fd[i] < 0)
            goto fail;
    }
    return true;
fail:
    plumos_panel_close(panel);
    return false;
}

static inline struct gbm_bo *plumos_panel_render(struct plumos_panel *panel, struct gbm_bo *input)
{
    unsigned int next;
    struct gbm_bo *output;
    rga_info_t src = {0}, dst = {0};
    int result;

    if (!input || !panel->initialized)
        return input;
    next = panel->front ^ 1;
    output = panel->scanout[next];
    if (!plumos_panel_linear(&panel->gbm, input))
        return NULL;
    src.fd = panel->gbm.get_fd(input);
    if (src.fd < 0)
        return NULL;
    dst.fd = panel->dma_fd[next];
    src.mmuFlag = dst.mmuFlag = 1;
    src.rotation = HAL_TRANSFORM_ROT_270;
    rga_set_rect(&src.rect, 0, 0, panel->height, panel->width,
                 panel->gbm.stride(input) / 4, panel->width, RK_FORMAT_BGRA_8888);
    rga_set_rect(&dst.rect, 0, 0, panel->width, panel->height,
                 panel->gbm.stride(output) / 4, panel->height, RK_FORMAT_BGRA_8888);
    result = panel->blit(&src, &dst, NULL);
    close(src.fd);
    return result == 0 ? output : NULL;
}

static inline void plumos_panel_submitted(struct plumos_panel *panel)
{
    if (panel->initialized) {
        panel->front ^= 1;
        panel->submitted = true;
    }
}

#endif

#ifndef FLUTTER_SHELL_PLATFORM_LINUX_CUSTOM_TEXTURE_CLASS_H_
#define FLUTTER_SHELL_PLATFORM_LINUX_CUSTOM_TEXTURE_CLASS_H_
#ifdef __linux__
#include <gtk/gtk.h>
#include <glib-object.h>
#include <flutter_linux/flutter_linux.h>
#endif

G_DECLARE_FINAL_TYPE(FlMyTextureGL,
                     fl_my_texture_gl,
                     FL,
                     MY_TEXTURE_GL,
                     FlTextureGL)

struct _FlMyTextureGL
{
    FlTextureGL parent_instance;
    uint32_t target;
    uint32_t name;
    uint32_t width;
    uint32_t height;
};


FlMyTextureGL *fl_my_texture_gl_new(uint32_t target,
                                    uint32_t name,
                                    uint32_t width,
                                    uint32_t height);
#endif // FLUTTER_SHELL_PLATFORM_LINUX_CUSTOM_TEXTURE_CLASS_H_

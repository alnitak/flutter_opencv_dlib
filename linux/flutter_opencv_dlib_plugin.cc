#include "include/flutter_opencv_dlib/flutter_opencv_dlib_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <GL/gl.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>

#include <iostream>
#include <memory>
#include <future>
#include <chrono>

#include "gl/fl_my_texture_gl.h"
#include "opencv_camera.h"


OpenCVCamera* openCVCamera = nullptr;
cv::VideoCapture cap;
GdkGLContext* context;
GdkWindow* window;
unsigned int texture_name;
g_autoptr(FlTexture) texture;
FlTextureRegistrar* texture_registrar;
FlMyTextureGL* myTexture;
int width;
int height;

#define FLUTTER_OPENCV_DLIB_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_opencv_dlib_plugin_get_type(), \
                              FlutterOpencvDlibPlugin))

struct _FlutterOpencvDlibPlugin {
  GObject parent_instance;
  FlTextureRegistrar* texture_registrar;
  FlView* fl_view;
};

G_DEFINE_TYPE(FlutterOpencvDlibPlugin, flutter_opencv_dlib_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void flutter_opencv_dlib_plugin_handle_method_call(
    FlutterOpencvDlibPlugin* self,
    FlMethodCall* method_call) {
  std::cout << "***fl_view: " << self->fl_view << " " << self << std::endl;
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  // Get Dart arguments
  FlValue* args = fl_method_call_get_args(method_call);


  if (strcmp(method, "registerTexture") == 0) {
    FlValue *w = fl_value_lookup_string(args, "width");
    FlValue *h = fl_value_lookup_string(args, "height");
    width = 0;
    height = 0;
    if (w != nullptr) width = fl_value_get_int(w);
    if (h != nullptr) height = fl_value_get_int(h);
    if (width == 0 || height == 0) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "100",
        "MethodCall registerTexture() called without passing width and height parameters!",
        nullptr
      ));
    } else {
      window = gtk_widget_get_parent_window(GTK_WIDGET(self->fl_view));
      GError* error = NULL;
      context = gdk_window_create_gl_context(window, &error);
      gdk_gl_context_make_current(context);

      glGenTextures(1, &texture_name);
      glBindTexture(GL_TEXTURE_2D, texture_name);

      myTexture = fl_my_texture_gl_new(GL_TEXTURE_2D, texture_name, width, height);
      texture = FL_TEXTURE(myTexture);
      texture_registrar = self->texture_registrar;
      fl_texture_registrar_register_texture(texture_registrar, texture);
      fl_texture_registrar_mark_texture_frame_available(texture_registrar,
                                                        texture);
      g_autoptr(FlValue) result =
          fl_value_new_int(reinterpret_cast<int64_t>(texture));
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void flutter_opencv_dlib_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(flutter_opencv_dlib_plugin_parent_class)->dispose(object);
}

static void flutter_opencv_dlib_plugin_class_init(FlutterOpencvDlibPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_opencv_dlib_plugin_dispose;
}

static void flutter_opencv_dlib_plugin_init(FlutterOpencvDlibPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlutterOpencvDlibPlugin* plugin = FLUTTER_OPENCV_DLIB_PLUGIN(user_data);
  flutter_opencv_dlib_plugin_handle_method_call(plugin, method_call);
}

void flutter_opencv_dlib_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterOpencvDlibPlugin* plugin = FLUTTER_OPENCV_DLIB_PLUGIN(
      g_object_new(flutter_opencv_dlib_plugin_get_type(), nullptr));

  FlView* fl_view = fl_plugin_registrar_get_view(registrar);
  plugin->fl_view = fl_view;
  plugin->texture_registrar =
      fl_plugin_registrar_get_texture_registrar(registrar);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "flutter_opencv_dlib",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}


//////////////////////////////////////////////
// openCV camera functions used with ffi
//////////////////////////////////////////////
#include "../ios/Classes/cpp/common.h"  // for FFI define

FFI void openOpenCVCamera() {
  if (openCVCamera == nullptr)
    openCVCamera = new OpenCVCamera();

  openCVCamera->open(width, height);
}

FFI void startOpenCVCamera() {
  if (openCVCamera == nullptr)
    return;

  openCVCamera->start(
      context,
      texture_name,
      texture,
      texture_registrar);

}

FFI void stopOpenCVCamera() {
  if (openCVCamera == nullptr)
    return;

  openCVCamera->stop();
}

FFI u_char* getBMPCameraFrame(int32_t *retImgLength) {
  if (openCVCamera == nullptr || !openCVCamera->isCameraThredRunning())
    return nullptr;

  *retImgLength = 0;
  cv::Mat img = openCVCamera->getCurrentMatFrame();
  u_char* ret = matToBmp(img, retImgLength);
  return ret;
}

FFI u_char* getRAWCameraFrame(int32_t *width,
                           int32_t *height,
                           int32_t *bytesPerPixel,
                           int32_t *retImgLength) {
  if (openCVCamera == nullptr || !openCVCamera->isCameraThredRunning())
    return nullptr;

  cv::Mat frame = openCVCamera->getCurrentMatFrame();
  u_char* imgBytes = matToRaw(frame, width, height,
                        bytesPerPixel, retImgLength);
  return imgBytes;
}

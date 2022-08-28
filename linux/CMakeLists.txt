# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "flutter_opencv_dlib")
project(${PROJECT_NAME} LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 14)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "flutter_opencv_dlib_plugin")

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
#
# Any new source files that you add to the plugin should be added here.
add_library(${PLUGIN_NAME} SHARED
  flutter_opencv_dlib_plugin.cc
  ../ios/Classes/cpp/native-lib.cpp
  ../ios/Classes/cpp/facedetector.cpp
  ../ios/Classes/cpp/facerecognition.cpp
  ../ios/Classes/cpp/face_common.h
  ../ios/Classes/cpp/fixed_queue.h
  ../ios/Classes/cpp/common.cpp
  ../ios/Classes/cpp/common.h

#    https://github.com/lattice0/external_texture_flutter_linux
  gl/fl_my_texture_gl.cc
  opencv_camera.cpp
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
#apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "../ios/Classes/cpp/"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

target_link_libraries(${PLUGIN_NAME} PRIVATE
        # EGL
        # GLESv2
        # ${OpenCV_LIBS}
        opencv_core
        opencv_highgui
        opencv_imgproc
        opencv_imgcodecs
        dlib
        lapack
        cblas
        gif
    )

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(flutter_opencv_dlib_bundled_libraries
  ""
  PARENT_SCOPE
)

include_directories( /usr/include/glib-2.0/ )

find_package(OpenCV REQUIRED COMPONENTS core highgui imgproc imgcodecs)
include_directories( ${OpenCV_INCLUDE_DIRS} )

message(STATUS "OpenCV_DIR = ${OpenCV_DIR}")
message(STATUS "OpenCV_INCLUDE_DIRS = ${OpenCV_INCLUDE_DIRS}")
message(STATUS "OpenCV_LIBS = ${OpenCV_LIBS}")

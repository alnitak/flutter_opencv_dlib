set(PROJECT_NAME "flutter_opencv_dlib")
set(PLUGIN_NAME "flutter_opencv_dlib_plugin")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
set(LOCAL_C_INCLUDES "${LOCAL_C_INCLUDES} ${DLIB_DIR}/include")


# Sets the minimum version of CMake required to build the native
# library. You should either keep the default value or only pass a
# value of 3.4.0 or lower.
cmake_minimum_required(VERSION 3.4.1)


# Creates and names a library, sets it as either STATIC
# or SHARED, and provides the relative paths to its source code.
# You can define multiple libraries, and CMake builds it for you.
# Gradle automatically packages shared libraries with your APK.

add_library( # Sets the name of the library.
            flutter_opencv_dlib_plugin

             # Sets the library as a shared library.
             SHARED

             # Provides a relative path to your source file(s).
             # Associated headers in the same location as their source
             # file are automatically included.
             ../ios/Classes/cpp/native-lib.cpp
			 ../ios/Classes/cpp/facedetector.cpp
			 ../ios/Classes/cpp/facedetector.h
			 ../ios/Classes/cpp/facerecognition.cpp
			 ../ios/Classes/cpp/facerecognition.h
			 ../ios/Classes/cpp/face_common.h
			 ../ios/Classes/cpp/fixed_queue.h
			 ../ios/Classes/cpp/common.cpp
			 ../ios/Classes/cpp/common.h
             )

# Searches for a specified prebuilt library and stores the path as a
# variable. Because system libraries are included in the search path by
# default, you only need to specify the name of the public NDK library
# you want to add. CMake verifies that the library exists before
# completing its build.

find_library( # Sets the name of the path variable.
              log-lib

              # Specifies the name of the NDK library that
              # you want CMake to locate.
              log )

find_library( android-lib android )


target_link_libraries( # Specifies the target library.
                       flutter_opencv_dlib_plugin
					   lib_opencv

                       # Links the target library to the log library
                       # included in the NDK.
                       ${log-lib} )


set(DLIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/main/dlib)
set (OPENCV_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/main/opencv)

include_directories(${OPENCV_DIR}/include)
add_library(lib_opencv SHARED IMPORTED)
set_target_properties(lib_opencv PROPERTIES IMPORTED_LOCATION ${OPENCV_DIR}/${ANDROID_ABI}/libopencv_java4.so)

include_directories(${DLIB_DIR}/include)
add_library( lib_dlib SHARED IMPORTED )
target_link_libraries( flutter_opencv_dlib_plugin lib_dlib)
set_target_properties(lib_dlib PROPERTIES IMPORTED_LOCATION ${DLIB_DIR}/${ANDROID_ABI}/libdlib.so)



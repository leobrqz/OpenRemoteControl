cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

set(VELOPACK_SDK "${CMAKE_CURRENT_SOURCE_DIR}/../../build/dependencies/velopack/1.2.161")
if(NOT EXISTS "${VELOPACK_SDK}/include/Velopack.hpp")
  file(MAKE_DIRECTORY "${VELOPACK_SDK}")
  file(DOWNLOAD
    "https://github.com/velopack/velopack/releases/download/1.2.161/velopack_libc_1.2.161.zip"
    "${VELOPACK_SDK}/sdk.zip"
    EXPECTED_HASH SHA256=31de8f2cf05a47bd5328a9f98b0c41aec1582156f6075f1058b26941f7f17c20
    TLS_VERIFY ON TIMEOUT 120)
  execute_process(COMMAND ${CMAKE_COMMAND} -E tar xf sdk.zip
    WORKING_DIRECTORY "${VELOPACK_SDK}" COMMAND_ERROR_IS_FATAL ANY)
endif()

# Do not inherit the runner / plugins' _HAS_EXCEPTIONS=0 setting.
set(JSON_SDK "${CMAKE_CURRENT_SOURCE_DIR}/../../build/dependencies/nlohmann/3.12.0")
if(NOT EXISTS "${JSON_SDK}/json.hpp")
  file(MAKE_DIRECTORY "${JSON_SDK}")
  file(DOWNLOAD "https://raw.githubusercontent.com/nlohmann/json/v3.12.0/single_include/nlohmann/json.hpp"
    "${JSON_SDK}/json.hpp"
    EXPECTED_HASH SHA256=aaf127c04cb31c406e5b04a63f1ae89369fccde6d8fa7cdda1ed4f32dfc5de63
    TLS_VERIFY ON TIMEOUT 60)
endif()
add_library(windows_updater STATIC "update_bridge.cpp")
target_compile_features(windows_updater PRIVATE cxx_std_17)
target_compile_options(windows_updater PRIVATE /EHsc /W4 /WX /wd4100)
target_compile_definitions(windows_updater PRIVATE _HAS_EXCEPTIONS=1 NOMINMAX
  "ORC_PRODUCT_VERSION=\"${FLUTTER_VERSION_MAJOR}.${FLUTTER_VERSION_MINOR}.${FLUTTER_VERSION_PATCH}\"")
if(DEFINED ENV{ORC_UPDATER_TESTING} AND "$ENV{ORC_UPDATER_TESTING}" STREQUAL "1")
  target_compile_definitions(windows_updater PRIVATE ORC_UPDATER_TESTING=1)
endif()
target_include_directories(windows_updater SYSTEM PRIVATE "${VELOPACK_SDK}/include" "${JSON_SDK}")
target_link_libraries(windows_updater PUBLIC flutter flutter_wrapper_app
  "${VELOPACK_SDK}/lib/velopack_libc_win_x64_msvc.dll.lib" shell32 winhttp)
add_executable(update_policy_test EXCLUDE_FROM_ALL "tests/update_policy_test.cpp")
target_compile_features(update_policy_test PRIVATE cxx_std_17)
target_compile_options(update_policy_test PRIVATE /EHsc /W4 /WX)
target_compile_definitions(update_policy_test PRIVATE _HAS_EXCEPTIONS=1 NOMINMAX)
set_target_properties(update_policy_test PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/updater-tests")
install(FILES "${VELOPACK_SDK}/lib/velopack_libc_win_x64_msvc.dll"
  DESTINATION "$<TARGET_FILE_DIR:${BINARY_NAME}>" RENAME "velopack_libc.dll" COMPONENT Runtime)
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.velopack"
  "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.nlohmann"
  DESTINATION "$<TARGET_FILE_DIR:${BINARY_NAME}>" COMPONENT Runtime)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE windows_updater)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

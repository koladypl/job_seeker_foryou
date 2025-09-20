# CMakeLists.txt at the project root

# 1. Project-level configuration and minimum CMake version
cmake_minimum_required(VERSION 3.10)
project(job_seeker_foryou LANGUAGES CXX)

# 2. Name of the executable (used by runner and install rules)
set(BINARY_NAME "job_seeker_foryou")

# 3. Multi‐config or single‐config setup
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
      CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()

# 4. Profile build mode reuses Release flags
set(CMAKE_EXE_LINKER_FLAGS_PROFILE    "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE             "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE           "${CMAKE_CXX_FLAGS_RELEASE}")

# 5. Use Unicode on Windows
add_definitions(-DUNICODE -D_UNICODE)

# 6. Common compile settings for all targets
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100" /EHsc)
  target_compile_definitions(${TARGET} PRIVATE
    "_HAS_EXCEPTIONS=0"
    "$<$<CONFIG:Debug>:_DEBUG>"
  )
endfunction()

# 7. Include the Flutter‐managed library
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# 8. Build the desktop runner (see windows/runner/CMakeLists.txt)
add_subdirectory("runner")

# 9. Include plugin registration and build rules
include(flutter/generated_plugins.cmake)

# === Installation rules ===

# Location next to the executable
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}"
      CACHE PATH "Installation directory" FORCE)
endif()

# Data and library bundle directories
set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR  "${CMAKE_INSTALL_PREFIX}")

# Install the executable
install(TARGETS ${BINARY_NAME} RUNTIME
        DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)

# Install ICU data for Flutter
install(FILES "${FLUTTER_ICU_DATA_FILE}"
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the Flutter engine library
install(FILES "${FLUTTER_LIBRARY}"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

# Install any bundled plugin libraries
if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES ${PLUGIN_BUNDLED_LIBRARIES}
          DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
endif()

# Copy native assets (e.g., shaders) into bundle
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

# Always refresh flutter_assets on each build
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
" COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install AOT library for Profile/Release only
install(FILES "${AOT_LIBRARY}"
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
        CONFIGURATIONS Profile;Release COMPONENT Runtime)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(SDK_ROOT "/opt/openwrt-sdk")
set(STAGING "${SDK_ROOT}/staging_dir/target-arm_cortex-a9_musl_eabi")

set(CMAKE_C_COMPILER "${SDK_ROOT}/staging_dir/toolchain-arm_cortex-a9_gcc-13.3.0_musl_eabi/bin/arm-openwrt-linux-muslgnueabi-gcc")
set(CMAKE_CXX_COMPILER "${SDK_ROOT}/staging_dir/toolchain-arm_cortex-a9_gcc-13.3.0_musl_eabi/bin/arm-openwrt-linux-muslgnueabi-g++")
set(CMAKE_AR "${SDK_ROOT}/staging_dir/toolchain-arm_cortex-a9_gcc-13.3.0_musl_eabi/bin/arm-openwrt-linux-muslgnueabi-ar")
set(CMAKE_STRIP "${SDK_ROOT}/staging_dir/toolchain-arm_cortex-a9_gcc-13.3.0_musl_eabi/bin/arm-openwrt-linux-muslgnueabi-strip")

set(CMAKE_FIND_ROOT_PATH "${STAGING}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(ENV{PKG_CONFIG_LIBDIR} "${STAGING}/usr/lib/pkgconfig:${STAGING}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${STAGING}")
set(ENV{STAGING_DIR} "${SDK_ROOT}/staging_dir")

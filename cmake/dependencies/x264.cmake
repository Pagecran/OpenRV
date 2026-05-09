#
# Copyright (C) 2026  Autodesk, Inc. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

RV_CREATE_STANDARD_DEPS_VARIABLES("RV_DEPS_X264" "${RV_DEPS_X264_VERSION}" "make" "sh")
RV_SHOW_STANDARD_DEPS_VARIABLES()

SET(_x264_git_ref
    "${RV_DEPS_X264_GIT_REF}"
)
IF(NOT _x264_git_ref)
  SET(_x264_git_ref
      "${_version}"
  )
ENDIF()

SET(_download_url
    "https://codeload.github.com/mirror/x264/tar.gz/${_x264_git_ref}"
)
SET(_download_hash
    ${RV_DEPS_X264_DOWNLOAD_HASH}
)

IF(RV_TARGET_WINDOWS)
  SET(_make_command
      make
  )
  SET(_x264_lib
      ${_lib_dir}/libx264.lib
  )
ELSE()
  SET(_x264_lib
      ${_lib_dir}/libx264.a
  )
ENDIF()

SET(_pkgconfig_dir
    ${_lib_dir}/pkgconfig
)
SET(_x264_pc
    ${_pkgconfig_dir}/x264.pc
)

SET(_configure_options
    ""
)
LIST(APPEND _configure_options "--prefix=${_install_dir}")
LIST(APPEND _configure_options "--bindir=${_bin_dir}")
LIST(APPEND _configure_options "--libdir=${_lib_dir}")
LIST(APPEND _configure_options "--includedir=${_include_dir}")
LIST(APPEND _configure_options "--enable-static")
LIST(APPEND _configure_options "--disable-cli")
LIST(APPEND _configure_options "--disable-opencl")
IF(NOT RV_TARGET_WINDOWS)
  LIST(APPEND _configure_options "--enable-pic")
ENDIF()

IF(RV_TARGET_WINDOWS)
  SET(_configure_env
      ${CMAKE_COMMAND} -E env "CC=cl" "AS=nasm"
  )
ELSE()
  SET(_configure_env
      ${CMAKE_COMMAND} -E env
  )
ENDIF()

EXTERNALPROJECT_ADD(
  ${_target}
  DOWNLOAD_NAME ${_target}_${_version}.tar.gz
  DOWNLOAD_DIR ${RV_DEPS_DOWNLOAD_DIR}
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  SOURCE_DIR ${_source_dir}
  INSTALL_DIR ${_install_dir}
  URL ${_download_url}
  URL_MD5 ${_download_hash}
  CONFIGURE_COMMAND ${_configure_env} ${_configure_command} ./configure ${_configure_options}
  BUILD_COMMAND ${_make_command} -j${_cpu_count}
  INSTALL_COMMAND ${_make_command} install
  BUILD_IN_SOURCE TRUE
  BUILD_ALWAYS FALSE
  BUILD_BYPRODUCTS ${_x264_lib} ${_x264_pc}
  USES_TERMINAL_BUILD TRUE
)

RV_ADD_IMPORTED_LIBRARY(
  NAME
  x264::x264
  TYPE
  STATIC
  LOCATION
  ${_x264_lib}
  INCLUDE_DIRS
  ${_include_dir}
  DEPENDS
  ${_target}
  ADD_TO_DEPS_LIST
)

SET_PROPERTY(
  GLOBAL APPEND
  PROPERTY "RV_FFMPEG_DEPENDS" RV_DEPS_X264
)
SET_PROPERTY(
  GLOBAL APPEND
  PROPERTY "RV_FFMPEG_EXTRA_C_OPTIONS" "--extra-cflags=-I${_include_dir}"
)
IF(RV_TARGET_WINDOWS)
  SET_PROPERTY(
    GLOBAL APPEND
    PROPERTY "RV_FFMPEG_EXTRA_LIBPATH_OPTIONS" "--extra-ldflags=-LIBPATH:${_lib_dir}"
  )
ELSE()
  SET_PROPERTY(
    GLOBAL APPEND
    PROPERTY "RV_FFMPEG_EXTRA_LIBPATH_OPTIONS" "--extra-ldflags=-L${_lib_dir}"
  )
ENDIF()
SET_PROPERTY(
  GLOBAL APPEND
  PROPERTY "RV_FFMPEG_EXTERNAL_LIBS" "--enable-gpl"
)
SET_PROPERTY(
  GLOBAL APPEND
  PROPERTY "RV_FFMPEG_EXTERNAL_LIBS" "--enable-version3"
)
SET_PROPERTY(
  GLOBAL APPEND
  PROPERTY "RV_FFMPEG_EXTERNAL_LIBS" "--enable-libx264"
)
SET_PROPERTY(
  GLOBAL APPEND
  PROPERTY "RV_FFMPEG_PKG_CONFIG_PATHS" "${_pkgconfig_dir}"
)

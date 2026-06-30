#
# Copyright (C) 2022  Autodesk, Inc. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

SET(RV_DEPS_WIN_PERL_ROOT
    ""
    CACHE STRING "Path to Windows perl root"
)

STRING(REPLACE "." "_" _version_underscored ${_version})

IF(RV_TARGET_WINDOWS
   AND (NOT RV_DEPS_WIN_PERL_ROOT
        OR RV_DEPS_WIN_PERL_ROOT STREQUAL "")
)
  MESSAGE(
    FATAL_ERROR
      "Unable to build without a RV_DEPS_WIN_PERL_ROOT. OpenSSL requires a Windows native perl interpreter to build (it recommends https://strawberryperl.com/). Example -DRV_DEPS_WIN_PERL_ROOT=c:/Strawberry/perl/bin"
  )
ENDIF()

SET(_make_command_script
    "${PROJECT_SOURCE_DIR}/src/build/make_openssl.py"
)
SET(_make_command
    python3 "${_make_command_script}"
)

LIST(APPEND _make_command "--source-dir")
LIST(APPEND _make_command ${_source_dir})
LIST(APPEND _make_command "--output-dir")
LIST(APPEND _make_command ${_install_dir})

LIST(APPEND _make_command "--vfx_platform")
LIST(APPEND _make_command ${RV_VFX_CY_YEAR})

IF(RV_TARGET_WINDOWS)
  LIST(APPEND _make_command "--perlroot")
  LIST(APPEND _make_command ${RV_DEPS_WIN_PERL_ROOT})
ENDIF()

IF(APPLE)
  IF(RV_TARGET_APPLE_X86_64)
    SET(__openssl_arch__
        x86_64
    )
  ELSEIF(RV_TARGET_APPLE_ARM64)
    SET(__openssl_arch__
        arm64
    )
  ENDIF()
  LIST(APPEND _make_command --arch=-${__openssl_arch__})
ENDIF()

EXTERNALPROJECT_ADD(
  ${_target}
  DOWNLOAD_NAME ${_target}_${_version}.zip
  DOWNLOAD_DIR ${RV_DEPS_DOWNLOAD_DIR}
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  SOURCE_DIR ${_source_dir}
  INSTALL_DIR ${_install_dir}
  URL ${_download_url}
  URL_MD5 ${_download_hash}
  CONFIGURE_COMMAND ${_make_command} --configure
  BUILD_COMMAND ${_make_command} --build
  INSTALL_COMMAND ${_make_command} --install
  BUILD_IN_SOURCE TRUE
  BUILD_ALWAYS FALSE
  BUILD_BYPRODUCTS ${_crypto_lib} ${_ssl_lib}
  USES_TERMINAL_BUILD TRUE
)

FILE(MAKE_DIRECTORY ${_include_dir})

IF(RV_TARGET_WINDOWS)
  SET(_openssl_pkgconfig_dir
      ${_install_dir}/lib/pkgconfig
  )
  FILE(MAKE_DIRECTORY ${_openssl_pkgconfig_dir})
  FILE(
    WRITE
    ${_openssl_pkgconfig_dir}/libcrypto.pc
    "prefix=${_install_dir}\nexec_prefix=\${prefix}\nlibdir=\${exec_prefix}/lib\nincludedir=\${prefix}/include\n\nName: OpenSSL-libcrypto\nDescription: OpenSSL cryptography library\nVersion: ${_version}\nLibs: -L\${libdir} -lcrypto\nCflags: -I\${includedir}\n"
  )
  FILE(
    WRITE
    ${_openssl_pkgconfig_dir}/libssl.pc
    "prefix=${_install_dir}\nexec_prefix=\${prefix}\nlibdir=\${exec_prefix}/lib\nincludedir=\${prefix}/include\n\nName: OpenSSL-libssl\nDescription: Secure Sockets Layer and cryptography libraries\nVersion: ${_version}\nRequires.private: libcrypto\nLibs: -L\${libdir} -lssl\nCflags: -I\${includedir}\n"
  )
  FILE(
    WRITE
    ${_openssl_pkgconfig_dir}/openssl.pc
    "prefix=${_install_dir}\nexec_prefix=\${prefix}\nlibdir=\${exec_prefix}/lib\nincludedir=\${prefix}/include\n\nName: OpenSSL\nDescription: Secure Sockets Layer and cryptography libraries and tools\nVersion: ${_version}\nRequires: libssl libcrypto\n"
  )
  ADD_CUSTOM_COMMAND(
    TARGET ${_target}
    POST_BUILD
    COMMENT "Renaming the openssl import libs to the name FFmpeg is expecting"
    COMMAND ${CMAKE_COMMAND} -E copy ${_install_dir}/lib/libssl.lib ${_lib_dir}/ssl.lib
    COMMAND ${CMAKE_COMMAND} -E copy ${_install_dir}/lib/libcrypto.lib ${_lib_dir}/crypto.lib
  )
ENDIF()

ADD_LIBRARY(OpenSSL::Crypto SHARED IMPORTED GLOBAL)
ADD_DEPENDENCIES(OpenSSL::Crypto ${_target})
SET_PROPERTY(
  TARGET OpenSSL::Crypto
  PROPERTY IMPORTED_LOCATION ${_crypto_lib}
)
SET_PROPERTY(
  TARGET OpenSSL::Crypto
  PROPERTY IMPORTED_SONAME ${_crypto_lib_name}
)
IF(RV_TARGET_WINDOWS)
  SET_PROPERTY(
    TARGET OpenSSL::Crypto
    PROPERTY IMPORTED_IMPLIB ${_implibpath_crypto}
  )
ENDIF()
TARGET_INCLUDE_DIRECTORIES(
  OpenSSL::Crypto
  INTERFACE ${_include_dir}
)
LIST(APPEND RV_DEPS_LIST OpenSSL::Crypto)

ADD_LIBRARY(OpenSSL::SSL SHARED IMPORTED GLOBAL)
ADD_DEPENDENCIES(OpenSSL::SSL ${_target})
SET_PROPERTY(
  TARGET OpenSSL::SSL
  PROPERTY IMPORTED_LOCATION ${_ssl_lib}
)
SET_PROPERTY(
  TARGET OpenSSL::SSL
  PROPERTY IMPORTED_SONAME ${_ssl_lib_name}
)
IF(RV_TARGET_WINDOWS)
  SET_PROPERTY(
    TARGET OpenSSL::SSL
    PROPERTY IMPORTED_IMPLIB ${_implibpath_ssl}
  )
ENDIF()
TARGET_INCLUDE_DIRECTORIES(
  OpenSSL::SSL
  INTERFACE ${_include_dir}
)
LIST(APPEND RV_DEPS_LIST OpenSSL::SSL)

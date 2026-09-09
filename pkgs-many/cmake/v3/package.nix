{
  version,
  src-hash,
  isMinimalBuild ? false,
  withNcurses ? false,
  withQt ? false,
  buildDocs ? !isMinimalBuild,
  useOpenSSL ? !isMinimalBuild,
  mkVariantPassthru,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  fetchurl,
  replaceVars,
  buildPackages,
  bzip2,
  curl,
  expat,
  libarchive,
  libuv,
  ncurses,
  openssl,
  pkg-config,
  rhash,
  sphinx,
  texinfo,
  xz,
  zlib,
  libsForQt5,
  gitUpdater,
  ps,

  # for passthru.tests
  mesa,
  gtest,
  spdlog,
}:

let
  inherit (libsForQt5) qtbase wrapQtAppsHook;
  inherit (stdenv.hostPlatform) isCygwin isDarwin isFreeBSD;
  useSharedLibraries = (!isMinimalBuild && !isCygwin);
in
# Minimal, bootstrap cmake does not have toolkits
assert isMinimalBuild -> (!withNcurses && !withQt);
stdenv.mkDerivation (finalAttrs: {
  pname =
    "cmake"
    + lib.optionalString isMinimalBuild "-minimal"
    + lib.optionalString withNcurses "-cursesUI"
    + lib.optionalString withQt "-qt5UI";
  inherit version;

  src = fetchurl {
    url = "https://cmake.org/files/v${lib.versions.majorMinor finalAttrs.version}/cmake-${finalAttrs.version}.tar.gz";
    hash = src-hash;
  };

  patches = [
    # Add NIXPKGS_CMAKE_PREFIX_PATH to cmake which is like CMAKE_PREFIX_PATH
    # except it is not searched for programs
    ./000-nixpkgs-cmake-prefix-path.diff
    # Don't search in non-Nix locations such as /usr, but do search in our libc.
    ./001-search-path.diff
    # Don't depend on frameworks.
    # TODO: support darwin
    # ./002-application-services.diff
    # Derived from https://github.com/libuv/libuv/commit/1a5d4f08238dd532c3718e210078de1186a5920d
    ./003-libuv-application-services.diff
  ]
  ++ lib.optional isCygwin ./004-cygwin.diff
  # Derived from https://github.com/curl/curl/commit/31f631a142d855f069242f3e0c643beec25d1b51
  ++ lib.optional (isDarwin && isMinimalBuild) ./005-remove-systemconfiguration-dep.diff
  # On Darwin, always set CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG.
  ++ lib.optional isDarwin ./006-darwin-always-set-runtime-c-flag.diff
  # On platforms where ps is not part of stdenv, patch the invocation of ps to use an absolute path.
  ++ lib.optional (isDarwin || isFreeBSD) (
    replaceVars ./007-darwin-bsd-ps-abspath.diff {
      ps = lib.getExe ps;
    }
  );

  outputs = [
    "out"
  ]
  ++ lib.optionals buildDocs [
    "man"
    "info"
  ];
  separateDebugInfo = true;
  setOutputFlags = false;

  setupHooks = [
    ../setup-hook.sh
    ../check-pc-files-hook.sh
  ];

  depsBuildBuild = [ buildPackages.stdenv.cc ];

  nativeBuildInputs =
    finalAttrs.setupHooks
    ++ [
      pkg-config
    ]
    ++ lib.optionals buildDocs [ texinfo ]
    ++ lib.optionals withQt [ wrapQtAppsHook ];

  buildInputs =
    lib.optionals useSharedLibraries [
      bzip2
      curl.minimal
      expat
      libarchive
      xz
      zlib
      libuv
      rhash
    ]
    ++ lib.optional useOpenSSL openssl
    ++ lib.optional withNcurses ncurses
    ++ lib.optional withQt qtbase;

  preConfigure = ''
    fixCmakeFiles .
    substituteInPlace Modules/Platform/UnixPaths.cmake \
      --subst-var-by libc_bin ${lib.getBin stdenv.cc.libc} \
      --subst-var-by libc_dev ${lib.getDev stdenv.cc.libc} \
      --subst-var-by libc_lib ${lib.getLib stdenv.cc.libc}
    # CC_FOR_BUILD and CXX_FOR_BUILD are used to bootstrap cmake
    local -a flagsArray=(
      "--parallel=''${NIX_BUILD_CORES:-1}"
      "CC=$CC_FOR_BUILD"
      "CXX=$CXX_FOR_BUILD"
    )
    concatTo flagsArray configureFlags cmakeFlags
    configureFlags=("''${flagsArray[@]}")
  '';

  # The configuration script is not autoconf-based, although being similar;
  # triples and other interesting info are passed via CMAKE_* environment
  # variables and commandline switches
  configurePlatforms = [ ];

  configureFlags = [
    "CXXFLAGS=-Wno-elaborated-enum-base"
    "--docdir=share/doc/${finalAttrs.pname}-${finalAttrs.version}"
  ]
  ++ (
    if useSharedLibraries then
      [
        "--no-system-cppdap"
        "--no-system-jsoncpp"
        "--system-libs"
      ]
    else
      [
        "--no-system-libs"
      ]
  )
  ++ lib.optional withQt "--qt-gui"
  ++ lib.optionals buildDocs [
    "--sphinx-build=${buildPackages.sphinx}/bin/sphinx-build"
    "--sphinx-info"
    "--sphinx-man"
  ]
  # Workaround https://gitlab.kitware.com/cmake/cmake/-/issues/20568
  ++ lib.optionals stdenv.hostPlatform.is32bit [
    "CFLAGS=-D_FILE_OFFSET_BITS=64"
    "CXXFLAGS=-D_FILE_OFFSET_BITS=64"
  ]
  ++ [
    "--"
    # We should set the proper `CMAKE_SYSTEM_NAME`.
    # http://www.cmake.org/Wiki/CMake_Cross_Compiling
    #
    # Unfortunately cmake seems to expect absolute paths for ar, ranlib, and
    # strip. Otherwise they are taken to be relative to the source root of the
    # package being built.
    (lib.cmakeFeature "CMAKE_CXX_COMPILER" "${stdenv.cc.targetPrefix}c++")
    (lib.cmakeFeature "CMAKE_C_COMPILER" "${stdenv.cc.targetPrefix}cc")
    (lib.cmakeFeature "CMAKE_AR" "${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ar")
    (lib.cmakeFeature "CMAKE_RANLIB" "${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ranlib")
    (lib.cmakeFeature "CMAKE_STRIP" "${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}strip")

    (lib.cmakeBool "CMAKE_USE_OPENSSL" useOpenSSL)
    (lib.cmakeBool "BUILD_CursesDialog" withNcurses)
  ];

  # `pkgsCross.musl64.cmake.override { stdenv = pkgsCross.musl64.llvmPackages_16.libcxxStdenv; }`
  # fails with `The C++ compiler does not support C++11 (e.g.  std::unique_ptr).`
  # The cause is a compiler warning `warning: argument unused during compilation: '-pie' [-Wunused-command-line-argument]`
  # interfering with the feature check.
  env.NIX_CFLAGS_COMPILE = "-Wno-unused-command-line-argument";

  # make install attempts to use the just-built cmake
  preInstall = lib.optionalString (stdenv.isCross) ''
    sed -i 's|bin/cmake|${buildPackages.cmake.minimal}/bin/cmake|g' Makefile
  '';

  doCheck = false; # fails

  passthru = mkVariantPassthru variantArgs // {
    configurePhaseHook = ../configure-phase-hook.sh;
    updateScript = gitUpdater {
      url = "https://gitlab.kitware.com/cmake/cmake.git";
      rev-prefix = "v";
      ignoredVersions = "-"; # -rc1 and friends
    };
    tests = {
      inherit mesa gtest spdlog;
    };
  };

  meta = {
    homepage = "https://cmake.org/";
    description = "Cross-platform, open-source build system generator";
    longDescription = ''
      CMake is an open-source, cross-platform family of tools designed to build,
      test and package software. CMake is used to control the software
      compilation process using simple platform and compiler independent
      configuration files, and generate native makefiles and workspaces that can
      be used in the compiler environment of your choice.
    '';
    changelog = "https://cmake.org/cmake/help/v${lib.versions.majorMinor finalAttrs.version}/release/${lib.versions.majorMinor finalAttrs.version}.html";
    license = lib.licenses.bsd3;

    platforms = lib.platforms.all;
    mainProgram = "cmake";
    broken = (withQt && isDarwin);
  };
})

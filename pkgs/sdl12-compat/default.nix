{
  lib,
  sdl2-compat,
  cmake,
  autoSignDarwinBinariesHook,
  fetchFromGitHub,
  libGLU,
  libiconv,
  libx11,
  mesa,
  pkg-config,
  pkg-config-unwrapped,
  stdenv,
  testers,

  libGLSupported ? lib.elem stdenv.hostPlatform.system mesa.meta.platforms,
  openglSupport ? libGLSupported,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sdl12-compat";
  version = "1.2.76";

  src = fetchFromGitHub {
    owner = "libsdl-org";
    repo = "sdl12-compat";
    tag = "release-${finalAttrs.version}";
    hash = "sha256-hSHtYFn4gr8Y9cNyLBT6frDgidNCRENPtTrtGfgH3po=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
    pkg-config
  ]
  ++ lib.optionals (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64) [
    autoSignDarwinBinariesHook
  ];

  # re-export PKG_CHECK_MODULES m4 macro used by sdl.m4
  propagatedNativeBuildInputs = [ pkg-config-unwrapped ];

  buildInputs = [
    libx11
    sdl2-compat
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    libiconv
  ]
  ++ lib.optionals openglSupport [ libGLU ];

  dontPatchELF = true; # don't strip rpath

  cmakeFlags =
    let
      rpath = lib.makeLibraryPath [ sdl2-compat ];
    in
    [
      (lib.cmakeFeature "CMAKE_INSTALL_RPATH" rpath)
      (lib.cmakeFeature "CMAKE_BUILD_RPATH" rpath)
      (lib.cmakeBool "SDL12TESTS" finalAttrs.finalPackage.doCheck)
    ];

  # Darwin fails with "Critical error: required built-in appearance SystemAppearance not found"
  doCheck = !stdenv.hostPlatform.isDarwin;
  checkPhase = ''
    runHook preCheck
    ./test/testver
    runHook postCheck
  '';

  postInstall = ''
    # allow as a drop in replacement for SDL
    ln -s $out/lib/pkgconfig/sdl12_compat.pc $out/lib/pkgconfig/sdl.pc
  '';

  patches = [
    # The setup hook scans paths of buildInputs to find SDL related packages and
    # adds their include and library paths to environment variables. The sdl-config
    # is patched to use these variables to produce correct flags for compiler.
    ./find-headers.patch
  ];
  setupHook = ./setup-hook.sh;

  passthru.tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;

  meta = {
    homepage = "https://www.libsdl.org/";
    description = "Cross-platform multimedia library - build SDL 1.2 applications against 2.0";
    license = lib.licenses.zlib;
    mainProgram = "sdl-config";
    platforms = lib.platforms.all;
    pkgConfigModules = [
      "sdl"
      "sdl12_compat"
    ];
  };
})

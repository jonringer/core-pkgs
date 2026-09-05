{
  lib,
  stdenv,
  fetchurl,
  cmake,
  pkg-config,
  libGL,
  libGLU,
  libxi,
  libxrandr,
  libxxf86vm,
  libxext,
  libx11,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "freeglut";
  version = "3.8.0";

  src = fetchurl {
    url = "https://github.com/freeglut/freeglut/releases/download/v${finalAttrs.version}/freeglut-${finalAttrs.version}.tar.gz";
    hash = "sha256-Z03K/yUBDgnkUK7EWLiHDZ6YxG+ZU420V6tlmzIdmYk=";
  };

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
    pkg-config
  ];

  buildInputs = [
    libGL
    libGLU
    libxi
    libxrandr
    libxxf86vm
    libxext
    libx11
  ];

  cmakeBuildType = "Release";

  cmakeFlags = [
    "-DFREEGLUT_BUILD_DEMOS=OFF"
    "-DCMAKE_INSTALL_LIBDIR=lib"
  ];

  meta = {
    description = "Open-source alternative to the OpenGL Utility Toolkit (GLUT) library";
    homepage = "https://freeglut.sourceforge.net/";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})

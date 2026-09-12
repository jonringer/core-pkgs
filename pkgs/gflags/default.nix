{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  enableShared ? !stdenv.hostPlatform.isStatic,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gflags";
  version = "2.3.1";

  outputs = [
    "out"
    "include"
  ];
  outputInclude = "include";

  src = fetchFromGitHub {
    owner = "gflags";
    repo = "gflags";
    tag = "v${finalAttrs.version}";
    hash = "sha256-haLm7T0ZrXLuGMYEszhKkBJEMV9SUjos5X7vXlHd0uU=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];

  # This isn't used by the build and breaks the CMake build on case-insensitive filesystems (e.g., on Darwin)
  preConfigure = "rm BUILD";

  cmakeBuildType = "Release";

  cmakeFlags = [
    "-DGFLAGS_BUILD_SHARED_LIBS=${if enableShared then "ON" else "OFF"}"
    "-DGFLAGS_BUILD_STATIC_LIBS=ON"
  ];

  meta = {
    description = "C++ library that implements commandline flags processing";
    homepage = "https://gflags.github.io/gflags/";
    changelog = "https://github.com/gflags/gflags/blob/${finalAttrs.src.tag}/ChangeLog.txt";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
})

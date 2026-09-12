{
  lib,
  stdenv,
  cmake,
  fetchFromGitHub,
  fetchpatch,
  onetbb,

  # TBB doesn't support being built static
  useTBB ? !stdenv.hostPlatform.isStatic,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libblake3";
  version = "1.8.7";

  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "BLAKE3-team";
    repo = "BLAKE3";
    tag = finalAttrs.version;
    hash = "sha256-QWNdJh9wSKoc171t+rNei6OF3ANb2K4Oi+3VHEy1BiQ=";
  };

  sourceRoot = finalAttrs.src.name + "/c";

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];

  propagatedBuildInputs = lib.optionals useTBB [
    onetbb
  ];

  cmakeFlags = [
    (lib.cmakeBool "BLAKE3_USE_TBB" useTBB)
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!stdenv.hostPlatform.isStatic))
  ];

  meta = {
    description = "Official C implementation of BLAKE3";
    homepage = "https://github.com/BLAKE3-team/BLAKE3/tree/master/c";
    license = with lib.licenses; [
      asl20
      cc0
    ];
    platforms = lib.platforms.all;
  };
})

{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,

  callPackage,

  # for passthru.tests
  imagemagick,
  libheif,
  gst_all_1,
}:

stdenv.mkDerivation (finalAttrs: {
  version = "1.1.2";
  pname = "libde265";

  outputs = [
    "out"
    "include"
  ];
  outputInclude = "include";

  src = fetchFromGitHub {
    owner = "strukturag";
    repo = "libde265";
    tag = "v${finalAttrs.version}";
    hash = "sha256-dXUkSGviRfQkWacxMpH2vyLiSMvsetFw6ncrTW1SZaQ=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
    pkg-config
  ];

  passthru.tests = {
    inherit imagemagick libheif;
    inherit (gst_all_1) gst-plugins-bad;

    test-corpus-decode = callPackage ./test-corpus-decode.nix {
      libde265 = finalAttrs.finalPackage;
    };
  };

  meta = {
    homepage = "https://github.com/strukturag/libde265";
    changelog = "https://github.com/strukturag/libde265/releases/tag/${finalAttrs.src.tag}";
    description = "Open h.265 video codec implementation";
    mainProgram = "dec265";
    license = lib.licenses.lgpl3;
    platforms = lib.platforms.unix;
  };
})

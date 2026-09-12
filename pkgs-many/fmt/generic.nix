{
  version,
  src-hash,
  patches ? [ ],
  mkVariantPassthru,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  cmake,
  enableShared ? !stdenv.hostPlatform.isStatic,
  runUnitTests,

  # tests
  mpd ? null,
  openimageio ? null,
  fcitx5 ? null,
  spdlog,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fmt";
  inherit version;

  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = version;
    hash = src-hash;
  };

  patches = map (p: fetchpatch p) patches;

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];

  cmakeFlags = [ (lib.cmakeBool "BUILD_SHARED_LIBS" enableShared) ];

  passthru = mkVariantPassthru variantArgs // {
    tests = {
      unittests = runUnitTests finalAttrs.finalPackage;
      inherit spdlog;
    }
    // lib.optionalAttrs (mpd != null) { inherit mpd; }
    // lib.optionalAttrs (openimageio != null) { inherit openimageio; }
    // lib.optionalAttrs (fcitx5 != null) { inherit fcitx5; };
  };

  meta = {
    description = "Small, safe and fast formatting library";
    longDescription = ''
      fmt (formerly cppformat) is an open-source formatting library. It can be
      used as a fast and safe alternative to printf and IOStreams.
    '';
    homepage = "https://fmt.dev/";
    changelog = "https://github.com/fmtlib/fmt/blob/${version}/ChangeLog.rst";
    downloadPage = "https://github.com/fmtlib/fmt/";

    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "fmt_project" finalAttrs.version;
  };
})

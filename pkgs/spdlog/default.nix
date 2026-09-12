{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  cmake,
  fmt,
  catch2_3,
  staticBuild ? stdenv.hostPlatform.isStatic,
  runUnitTests,

  # passthru
  bear ? null,
  tiledb ? null,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "spdlog";
  version = "1.17.0";

  src = fetchFromGitHub {
    owner = "gabime";
    repo = "spdlog";
    tag = "v${finalAttrs.version}";
    hash = "sha256-bL3hQmERXNwGmDoi7+wLv/TkppGhG6cO47k1iZvJGzY=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];
  # Required to build tests, even if they aren't executed
  buildInputs = [ catch2_3 ];
  propagatedBuildInputs = [ fmt ];

  cmakeFlags = [
    (lib.cmakeBool "SPDLOG_BUILD_SHARED" (!staticBuild))
    (lib.cmakeBool "SPDLOG_BUILD_STATIC" staticBuild)
    (lib.cmakeBool "SPDLOG_BUILD_EXAMPLE" false)
    (lib.cmakeBool "SPDLOG_BUILD_BENCH" false)
    (lib.cmakeBool "SPDLOG_BUILD_TESTS" true)
    (lib.cmakeBool "SPDLOG_FMT_EXTERNAL" true)
  ];

  outputs = [
    "out"
    "doc"
    "dev"
  ];

  postInstall = ''
    mkdir -p $out/share/doc/spdlog
    cp -rv ../example $out/share/doc/spdlog

    substituteInPlace $dev/include/spdlog/tweakme.h \
      --replace-fail \
        '// #define SPDLOG_FMT_EXTERNAL' \
        '#define SPDLOG_FMT_EXTERNAL'
  '';

  passthru = {
    tests = {
      unittests = runUnitTests finalAttrs.finalPackage;
    }
    // lib.optionalAttrs (bear != null) { inherit bear; }
    // lib.optionalAttrs (tiledb != null) { inherit tiledb; };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Very fast, header only, C++ logging library";
    homepage = "https://github.com/gabime/spdlog";
    changelog = "https://github.com/gabime/spdlog/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "spdlog_project" finalAttrs.version;
  };
})

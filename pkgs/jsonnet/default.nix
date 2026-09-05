# jsonnet — Data templating language
{
  stdenv,
  lib,
  cmake,
  fetchFromGitHub,
  gtest,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "jsonnet";
  version = "0.22.0";

  src = fetchFromGitHub {
    rev = "v${finalAttrs.version}";
    owner = "google";
    repo = "jsonnet";
    sha256 = "sha256-3J1Rm5nDgE0casINMoEU7anuuoNmTYmuRorZwKefYSY=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];
  buildInputs = [ gtest ];

  cmakeFlags = [
    "-DUSE_SYSTEM_GTEST=ON"
    "-DBUILD_STATIC_LIBS=${if stdenv.hostPlatform.isStatic then "ON" else "OFF"}"
  ]
  ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    "-DBUILD_SHARED_BINARIES=${if stdenv.hostPlatform.isStatic then "OFF" else "ON"}"
  ];

  meta = {
    description = "Purely-functional configuration language that helps you define JSON data";
    homepage = "https://github.com/google/jsonnet";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})

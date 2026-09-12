{
  lib,
  stdenv,
  fetchFromGitHub,
  aws-c-common,
  cmake,
  nix,
}:

stdenv.mkDerivation rec {
  pname = "aws-c-sdkutils";
  version = "1.0.0";

  outputs = [
    "out"
    "include"
  ];
  outputInclude = "include";

  src = fetchFromGitHub {
    owner = "awslabs";
    repo = "aws-c-sdkutils";
    rev = "v${version}";
    hash = "sha256-SxEt4W5Bxdo+gJiP09FRKzGrqW/wO4NufRgBbWDph/g=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];

  buildInputs = [
    aws-c-common
  ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
  ];

  doCheck = true;

  passthru.tests = {
    inherit nix;
  };

  meta = {
    description = "AWS SDK utility library";
    homepage = "https://github.com/awslabs/aws-c-sdkutils";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "amazon" version;
  };
}

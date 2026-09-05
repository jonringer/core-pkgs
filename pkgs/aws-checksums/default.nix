{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  aws-c-common,
  nix,
}:

stdenv.mkDerivation rec {
  pname = "aws-checksums";
  version = "1.0.0";

  outputs = [
    "out"
    "include"
  ];
  outputInclude = "include";

  src = fetchFromGitHub {
    owner = "awslabs";
    repo = "aws-checksums";
    rev = "v${version}";
    sha256 = "sha256-Yvv4NT90715zMBqBeJz7o2WTDRSjszPpBsFGMVTMc4I=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];

  buildInputs = [ aws-c-common ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
  ];

  passthru.tests = {
    inherit nix;
  };

  meta = {
    description = "HW accelerated CRC32c and CRC32";
    homepage = "https://github.com/awslabs/aws-checksums";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "amazon" version;
  };
}

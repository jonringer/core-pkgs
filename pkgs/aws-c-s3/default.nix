{
  lib,
  stdenv,
  fetchFromGitHub,
  aws-c-auth,
  aws-c-cal,
  aws-c-common,
  aws-c-compression,
  aws-c-http,
  aws-c-io,
  aws-checksums,
  cmake,
  nix,
  s2n-tls,
}:

stdenv.mkDerivation rec {
  pname = "aws-c-s3";
  # nixpkgs-update: no auto update
  version = "1.0.0";

  outputs = [
    "out"
    "include"
  ];
  outputInclude = "include";

  src = fetchFromGitHub {
    owner = "awslabs";
    repo = "aws-c-s3";
    rev = "v${version}";
    hash = "sha256-Asva8mkL/+I0JB+CE2RjGy3md2Qn/52PCvWPKHCrwgM=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];

  buildInputs = [
    aws-c-auth
    aws-c-cal
    aws-c-common
    aws-c-compression
    aws-c-http
    aws-c-io
    aws-checksums
    s2n-tls
  ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
  ];

  passthru.tests = {
    inherit nix;
  };

  meta = {
    description = "C99 library implementation for communicating with the S3 service";
    homepage = "https://github.com/awslabs/aws-c-s3";
    license = lib.licenses.asl20;
    mainProgram = "s3";
    platforms = lib.platforms.unix;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "amazon" version;
  };
}

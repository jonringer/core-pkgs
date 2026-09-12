{
  lib,
  stdenv,
  fetchFromGitHub,
  aws-c-cal,
  aws-c-common,
  aws-c-compression,
  aws-c-http,
  aws-c-io,
  cmake,
  nix,
  s2n-tls,
}:

stdenv.mkDerivation rec {
  pname = "aws-c-mqtt";
  # nixpkgs-update: no auto update
  version = "1.0.0";

  outputs = [
    "out"
    "include"
  ];
  outputInclude = "include";

  src = fetchFromGitHub {
    owner = "awslabs";
    repo = "aws-c-mqtt";
    rev = "v${version}";
    hash = "sha256-6k3Ca25fRPqV+QW0+VEUdbB0JUFjqvZo8R7eaiEby0c=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];

  buildInputs = [
    aws-c-cal
    aws-c-common
    aws-c-compression
    aws-c-http
    aws-c-io
    s2n-tls
  ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
  ];

  passthru.tests = {
    inherit nix;
  };

  meta = {
    description = "C99 implementation of the MQTT 3.1.1 specification";
    homepage = "https://github.com/awslabs/aws-c-mqtt";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "amazon" version;
  };
}

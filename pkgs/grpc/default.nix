{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  cmake,
  zlib,
  c-ares,
  pkg-config,
  re2,
  openssl,
  protobuf,
  abseil-cpp,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "grpc";
  version = "1.83.1";

  outputs = [
    "out"
    "include"
  ];
  outputInclude = "include";

  src = fetchFromGitHub {
    owner = "grpc";
    repo = "grpc";
    tag = "v${finalAttrs.version}";
    hash = "sha256-h2F+lKF9GH5CGjzS5326ovLUHbYwsPjoqmb8Ljgj2ao=";
    fetchSubmodules = true;
  };

  patches = [
    (fetchpatch {
      # armv6l support, https://github.com/grpc/grpc/pull/21341
      name = "grpc-link-libatomic.patch";
      url = "https://github.com/lopsided98/grpc/commit/a9b917666234f5665c347123d699055d8c2537b2.patch";
      hash = "sha256-Lm0GQsz/UjBbXXEE14lT0dcRzVmCKycrlrdBJj+KLu8=";
    })
  ];

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
    pkg-config
  ];

  propagatedBuildInputs = [
    c-ares
    re2
    zlib
    abseil-cpp
  ];

  buildInputs = [
    openssl
    protobuf
    # TODO(corepkgs): Port libnsl for NIS/NIS+ support on Linux
  ];

  cmakeFlags = [
    "-DgRPC_ZLIB_PROVIDER=package"
    "-DgRPC_CARES_PROVIDER=package"
    "-DgRPC_RE2_PROVIDER=package"
    "-DgRPC_SSL_PROVIDER=package"
    "-DgRPC_PROTOBUF_PROVIDER=package"
    "-DgRPC_ABSL_PROVIDER=package"
    "-DBUILD_SHARED_LIBS=ON"
  ];

  cmakeBuildType = "Release";

  # CMake creates a build directory by default, this conflicts with the
  # bazel BUILD file on case-insensitive filesystems.
  preConfigure = ''
    rm -vf BUILD
  '';

  # When natively compiling, grpc_cpp_plugin is executed from the build directory,
  # needing to load dynamic libraries from the build directory.
  preBuild = ''
    export LD_LIBRARY_PATH=$(pwd)''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH
  '';

  env.NIX_CFLAGS_COMPILE = toString [
    "-Wno-error"
  ];

  meta = {
    description = "C based gRPC (C++, Python, Ruby, Objective-C, PHP, C#)";
    license = lib.licenses.asl20;
    homepage = "https://grpc.io/";
    platforms = lib.platforms.all;
    changelog = "https://github.com/grpc/grpc/releases/tag/v${finalAttrs.version}";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "grpc" finalAttrs.version;
  };
})

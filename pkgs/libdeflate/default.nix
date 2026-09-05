{
  lib,
  stdenv,
  fetchFromGitHub,
  fixDarwinDylibNames,
  pkgsStatic,
  cmake,
  zlib,
  testers,
  runUnitTests,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libdeflate";
  version = "1.26";

  outputs = [
    "out"
    "include"
  ];
  outputInclude = "include";

  src = fetchFromGitHub {
    owner = "ebiggers";
    repo = "libdeflate";
    rev = "v${finalAttrs.version}";
    hash = "sha256-QVF2XL8Qu3mTszKKtx+8BExkTGkpMANXjkAe3XXPUJQ=";
  };

  cmakeFlags = [
    "-DLIBDEFLATE_BUILD_TESTS=ON"
  ]
  ++ lib.optionals stdenv.hostPlatform.isStatic [ "-DLIBDEFLATE_BUILD_SHARED_LIB=OFF" ];

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin fixDarwinDylibNames;
  buildInputs = [ zlib ];

  passthru.tests = {
    static = pkgsStatic.libdeflate;
    pkg-config = testers.hasPkgConfigModules {
      package = finalAttrs.finalPackage;
    };
    unittests = runUnitTests finalAttrs.finalPackage;
  };

  meta = {
    description = "Fast DEFLATE/zlib/gzip compressor and decompressor";
    license = lib.licenses.mit;
    homepage = "https://github.com/ebiggers/libdeflate";
    changelog = "https://github.com/ebiggers/libdeflate/blob/v${finalAttrs.version}/NEWS.md";
    platforms = lib.platforms.unix ++ lib.platforms.windows;
    pkgConfigModules = [ "libdeflate" ];
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "libdeflate_project" finalAttrs.version;
  };
})

{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
}:

stdenv.mkDerivation rec {
  pname = "catch2";
  version = "3.16.0";

  outputs = [
    "out"
    "include"
  ];
  outputInclude = "include";

  src = fetchFromGitHub {
    owner = "catchorg";
    repo = "Catch2";
    rev = "v${version}";
    sha256 = "sha256-vvPZTQzLNGIcdDbuo0w6sQvxzLdKFCl2LNwcHu0d5I8=";
  };

  postPatch = ''
    substituteInPlace CMake/*.pc.in \
      --replace-fail "\''${prefix}/" ""
  '';

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];

  cmakeFlags = [
    "-H.."
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
    "-DCMAKE_INSTALL_LIBDIR=lib"
  ];

  meta = {
    description = "Multi-paradigm automated test framework for C++ and Objective-C (and, maybe, C)";
    homepage = "http://catch-lib.net";
    license = lib.licenses.boost;
    platforms = with lib.platforms; unix ++ windows;
  };
}

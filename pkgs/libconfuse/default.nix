{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  flex,
}:

stdenv.mkDerivation rec {
  pname = "libconfuse";
  version = "3.4";

  src = fetchFromGitHub {
    sha256 = "sha256-sC8O6vcMKvRdRCTXpKl6lgmzFUVG8/LBE7XsGX8F9e4=";
    rev = "v${version}";
    repo = "libconfuse";
    owner = "martinh";
  };

  postPatch = ''
    substituteInPlace tests/Makefile.am \
      --replace 'TESTS            += empty_string' "" \
      --replace 'TESTS            += print_filter' ""
  '';

  nativeBuildInputs = [
    autoreconfHook
    flex
  ];

  # On darwin the tests depend on the installed libraries because of install_name.
  doInstallCheck = true;
  installCheckTarget = "check";

  meta = {
    inherit (src.meta) homepage;
    description = "Small configuration file parser library for C";
    longDescription = ''
      libConfuse (previously libcfg) is a configuration file parser library
      written in C. It supports sections and (lists of) values, as well as
      some other features. It makes it very easy to add configuration file
      capability to a program using a simple API.

      The goal of libConfuse is not to be the configuration file parser library
      with a gazillion of features. Instead, it aims to be easy to use and
      quick to integrate with your code.
    '';
    license = lib.licenses.isc;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "libconfuse_project" version;
  };
}

{
  version,
  src-url,
  src-hash,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  perl,
}:

stdenv.mkDerivation {
  pname = "nasm";
  inherit version;

  src = fetchurl {
    url = src-url;
    hash = src-hash;
  };

  nativeBuildInputs = [ perl ];

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
  };

  meta = {
    homepage = "https://www.nasm.us/";
    description = "80x86 and x86-64 assembler designed for portability and modularity";
    platforms = lib.platforms.unix;
    mainProgram = "nasm";
    license = lib.licenses.bsd2;
  };
}

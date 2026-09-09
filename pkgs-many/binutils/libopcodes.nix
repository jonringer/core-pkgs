{
  lib,
  stdenv,
  callPackage,
  callFromScope,
}:

# LLVM needs these headers before the Darwin cctools wrapper can be evaluated.
let
  unwrapped = callPackage (callFromScope ./default.nix { variant = "unwrapped-all-targets"; }) { };
in
stdenv.mkDerivation {
  pname = "libopcodes";
  inherit (unwrapped) version;

  dontUnpack = true;
  dontBuild = true;
  dontInstall = true;
  propagatedBuildInputs = [
    unwrapped.dev
    unwrapped.lib
  ];

  passthru = {
    inherit (unwrapped) dev;
  };

  meta = {
    description = "Library from binutils for manipulating machine code";
    homepage = "https://www.gnu.org/software/binutils/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}

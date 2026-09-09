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
  pname = "libbfd";
  inherit (unwrapped) version;

  dontUnpack = true;
  dontBuild = true;
  dontInstall = true;
  propagatedBuildInputs = [
    unwrapped.dev
    unwrapped.lib
  ];

  passthru = {
    inherit (unwrapped) src dev plugin-api-header;
  };

  meta = {
    description = "Library for manipulating containers of machine code";
    longDescription = ''
      BFD is a library which provides a single interface to read and write
      object files, executables, archive files, and core files in any format.
      It is associated with GNU Binutils, and elsewhere often distributed with
      it.
    '';
    homepage = "https://www.gnu.org/software/binutils/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}

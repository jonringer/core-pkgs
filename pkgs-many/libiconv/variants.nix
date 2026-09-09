{
  lib,
  stdenv,
  libc,
}:
{
  darwin = {
    implementation = "darwin";
    version =
      (builtins.fromJSON (builtins.readFile ../../pkgs/sourceRelease/versions.json)).libiconv.version;
  };
  real = {
    implementation = "upstream";
    version = "1.18";
    hash = "sha256-Owj19Pm064LxUacEC/1v5sb7ki7+SxZZxm6pMydpZeg=";
    enableDarwinABICompat = false;
  };
  darwinABICompat = {
    implementation = "upstream";
    version = "1.18";
    hash = "sha256-Owj19Pm064LxUacEC/1v5sb7ki7+SxZZxm6pMydpZeg=";
    enableDarwinABICompat = true;
  };
}
//
  lib.optionalAttrs
    (lib.elem stdenv.hostPlatform.libc [
      "glibc"
      "musl"
      "nblibc"
      "wasilibc"
      "fblibc"
    ])
    {
      libc = {
        implementation = "libc";
        inherit (libc) version;
      };
    }

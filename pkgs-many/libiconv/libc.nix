{
  lib,
  libc,
  runCommand,
}:
let
  inherit (libc) pname version;
  libcDev = lib.getDev libc;
in
runCommand "${pname}-iconv-${version}" { } ''
  mkdir -p $out/include
  ln -sv ${libcDev}/include/iconv.h $out/include
''

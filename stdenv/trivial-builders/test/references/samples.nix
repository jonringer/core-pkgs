{
  lib,
  runCommand,
  writeText,
  emptyFile,
  emptyDirectory,
  coreutils,
  patch,
  zlib,
}:
{
  inherit
    coreutils
    patch
    zlib
    ;
  zlib-dev = zlib.dev;
  norefs = writeText "hi" "hello";
  norefsDup = writeText "hi" "hello";
  patchRef = writeText "hi" "patch ${patch}";
  patchRefDup = writeText "hi" "patch ${patch}";
  path = ./apath.txt;
  pathLike.outPath = ./apath.txt;
  patchCoreutilsRef = writeText "hi" "patch ${patch} ${coreutils}";
  selfRef = runCommand "self-ref-1" { } "echo $out >$out";
  selfRef2 = runCommand "self-ref-2" { } ''echo "${coreutils}, $out" >$out'';
  inherit
    emptyFile
    emptyDirectory
    ;
}

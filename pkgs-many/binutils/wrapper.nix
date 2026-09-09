{ noLibc, ... }:
{
  lib,
  wrapBintoolsWith,
  bintools,
  targetPackages,
  preLibcHeaders,
  ...
}@args:
(wrapBintoolsWith (
  {
    inherit bintools;
  }
  // lib.optionalAttrs noLibc { libc = targetPackages.preLibcHeaders or preLibcHeaders; }
  // builtins.removeAttrs args [
    "lib"
    "wrapBintoolsWith"
    "preLibcHeaders"
  ]
)).overrideAttrs
  (old: {
    passthru = old.passthru // {
      unwrapped = old.passthru.bintools;
    };
  })

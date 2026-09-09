{ callPackage, unixtools, ... }@args:
(unixtools.locale.override (
  builtins.removeAttrs args [
    "callPackage"
    "unixtools"
  ]
)).overrideAttrs
  (old: {
    passthru = old.passthru or { } // {
      data = callPackage ./darwin.nix { };
    };
  })

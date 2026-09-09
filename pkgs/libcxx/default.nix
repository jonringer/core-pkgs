{
  callPackage,
  stdenvNoCC,
  llvmPackages,
  ...
}@args:
let
  apple = callPackage ./darwin.nix { inherit stdenvNoCC; };
  package = if stdenvNoCC.hostPlatform.isDarwin then apple else llvmPackages.libcxx;
in
(package.override (
  builtins.removeAttrs args [
    "callPackage"
    "stdenvNoCC"
    "llvmPackages"
  ]
)).overrideAttrs
  (old: {
    passthru = old.passthru or { } // {
      inherit apple;
    };
  })

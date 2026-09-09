{
  callPackage,
  stdenvNoCC,
  llvmPackages,
  ...
}@args:
let
  package =
    if stdenvNoCC.hostPlatform.isDarwin then
      callPackage ./darwin.nix { inherit stdenvNoCC; }
    else if stdenvNoCC.hostPlatform.system == "riscv32-linux" then
      llvmPackages.libunwind
    else
      callPackage ./generic.nix { };
in
package.override (
  builtins.removeAttrs args [
    "callPackage"
    "stdenvNoCC"
    "llvmPackages"
  ]
)

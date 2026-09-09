{
  version,
  officialRelease ? null,
  gitRelease ? null,
  packageOlder,
  packageAtLeast,
  mkVariantPassthru,
  ...
}@variantArgs:

{
  lib,
  callPackage,
  stdenvAdapters,
  buildPackages,
  targetPackages,
  stdenv,
  pkgs,
  # This is the default binutils, but with *this* version of LLD rather
  # than the default LLVM version's, if LLD is the choice. We use these for
  # the `useLLVM` bootstrapping below.
  bootBintoolsNoLibc ? if stdenv.targetPlatform.linker == "lld" then null else pkgs.bintoolsNoLibc,
  bootBintools ? if stdenv.targetPlatform.linker == "lld" then null else pkgs.bintools,
  generateSplicesForMkScope,
  patchesFn ? lib.id,
  # Allows passthrough to packages via newScope in ./common/default.nix.
  # This makes it possible to do
  # `(llvmPackages.override { <someLlvmDependency> = bar; }).clang` and get
  # an llvmPackages whose packages are overridden in an internally consistent way.
  ...
}@packageSetArgs:

let
  # Keep scope construction independent of the LLVM derivation. Cross splicing
  # needs to inspect the scope before it can choose LLVM's dependencies.
  llvmPackages = callPackage (import ./scope.nix variantArgs) packageSetArgs;

  # The main LLVM library package from the scope
  llvmLib = llvmPackages.llvm;

in
# Return the LLVM library with the full package scope in passthru
llvmLib.overrideAttrs (oldAttrs: {
  passthru =
    (oldAttrs.passthru or { })
    // mkVariantPassthru variantArgs
    // {
      # Add the full package scope as 'pkgs' passthru (like Python)
      pkgs = llvmPackages;
      inherit variantArgs;
      # The inner llvm sets ekapkgs-update.skip since its file uses
      # `inherit version` and can't be updated directly. The outer
      # mkManyVariants wrapper CAN be updated via variants.nix, so
      # clear the skip flag.
      ekapkgs-update.skip = false;
    };
})

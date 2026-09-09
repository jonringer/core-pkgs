{
  version,
  officialRelease ? null,
  gitRelease ? null,
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
  inherit
    (import ./common/common-let.nix {
      inherit lib;
      inherit gitRelease officialRelease version;
    })
    releaseInfo
    ;
  inherit (releaseInfo) release_version;

  # Determine the attribute name for splicing (must match what's in top-level and aliases)
  # Use the old naming convention: "18", "19", etc. for splicing to work
  spliceAttrName = if (gitRelease != null) then "git" else lib.versions.major release_version;

in
lib.recurseIntoAttrs (
  callPackage ./common (
    {
      inherit (stdenvAdapters) overrideCC;
      inherit
        officialRelease
        gitRelease
        version
        patchesFn
        bootBintools
        bootBintoolsNoLibc
        ;

      otherSplices = generateSplicesForMkScope "llvmPackages_${spliceAttrName}";
    }
    // packageSetArgs # Allow overrides.
  )
)

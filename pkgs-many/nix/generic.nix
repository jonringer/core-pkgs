{
  version,
  hash,
  builderType ? "modular",
  needsBoost187 ? false,
  isGit ? false,
  rev ? null,
  mkVariantPassthru,
  packageOlder,
  packageAtLeast,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  runCommand,
  pkgs,
  pkgsi686Linux,
  pkgsStatic,
  config,
  generateSplicesForMkScope,
  nixDependencies,

  storeDir ? config.nix.storeDir or "/nix/store",
  stateDir ? config.nix.stateDir or "/nix/var",
  confDir ? "/etc",
}:

let
  # Boost 1.87 override for nix >= 2.33
  nixDeps =
    if needsBoost187 then
      nixDependencies.overrideScope (
        final: prev: {
          boost = pkgs.boost.v1_87;
        }
      )
    else
      nixDependencies;

  # Fetch source
  src =
    if isGit then
      fetchFromGitHub {
        owner = "NixOS";
        repo = "nix";
        inherit rev hash;
      }
    else
      fetchFromGitHub {
        owner = "NixOS";
        repo = "nix";
        tag = version;
        inherit hash;
      };

  # Effective version (git gets rev suffix)
  effectiveVersion = if isGit then "${version}_${lib.substring 0 8 rev}" else version;

  # Attribute name for this variant (used for splicing + tests)
  selfAttrName =
    if isGit then
      "git"
    else
      "v${builtins.replaceStrings [ "." ] [ "_" ] (lib.versions.majorMinor version)}";

  # Splice path for nixComponents scope.
  # Uses the two-level path ["nixVersions" "nixComponents_2_X"] to match the
  # backwards-compat nixVersions attr set, avoiding cycles that would occur
  # if we used a top-level nixComponents_2_X attr (which would need to go
  # through nix.v2_X.pkgs, creating infinite recursion with the splice resolution).
  nixComponentsAttrName =
    if isGit then
      "nixComponents_git"
    else
      "nixComponents_${builtins.replaceStrings [ "." ] [ "_" ] (lib.versions.majorMinor version)}";

  # Build the modular component scope
  nixComponents = nixDeps.callPackage ./modular/packages.nix {
    version = effectiveVersion;
    inherit src;
    nixDependencies = nixDeps;
    otherSplices = generateSplicesForMkScope [
      "nixVersions"
      nixComponentsAttrName
    ];
  };

  # Add passthru tests to a package
  addTests =
    selfAttributeName: pkg:
    let
      tests =
        pkg.tests or { }
        // import ./tests.nix {
          inherit
            runCommand
            lib
            stdenv
            pkgs
            pkgsi686Linux
            pkgsStatic
            ;
          inherit (pkg) version src;
          nix = pkg;
          self_attribute_name = selfAttributeName;
        };
    in
    pkg
    // {
      tests = pkg.tests or { } // tests;
      passthru = pkg.passthru or { } // {
        tests =
          lib.warn "nix.passthru.tests is deprecated. Use nix.tests instead." pkg.passthru.tests or { }
          // tests;
      };
    };

  # Dispatch based on builder type
  basePackage =
    if builderType == "monolithic" then
      nixDeps.callPackage
        (import ./common-meson.nix {
          inherit lib fetchFromGitHub;
          version = effectiveVersion;
          inherit hash;
          self_attribute_name = selfAttrName;
        })
        {
          inherit storeDir stateDir confDir;
        }
    else
      addTests selfAttrName nixComponents.nix-everything;

in
basePackage.overrideAttrs (oldAttrs: {
  passthru =
    (oldAttrs.passthru or { })
    // mkVariantPassthru variantArgs
    // {
      inherit variantArgs;
      # Individual component packages are accessible via nixVersions.nixComponents_2_X
      # (not via passthru.pkgs) to avoid infinite recursion with the splice infrastructure.
      ekapkgs-update.skip = false;
      ekapkgs-update.semver-strategy = "patch";
    };
})

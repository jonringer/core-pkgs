{ lib, config }:

{
# Intended to be an attrset of { "<exposed version>" = { version = "<full version>"; src = <path>; } }
# or a file containing such version information
# Type: AttrSet AttrSet
versions,

# Similar to versions, but instead contain deprecation and removal messages
# Only added when `config.allowAliases` is true
# This is passed the versions attr set to allow for directly referencing the version entries
# Type: AttrSet AttrSet -> AttrSet AttrSet.
aliases ? { ... }: { },

# A "projection" from the version set to a version to be used as the default
# Type: AttrSet package -> package
defaultSelector,

# Nix expression which takes version and package args, and returns an attrset to pass to mkDerivation
# Type: AttrSet -> AttrSet -> AttrSet
genericBuilder,
}:

# Some assertions as poor man's type checking
assert builtins.isFunction defaultSelector;

let
  versionsRaw = if builtins.isPath versions then import versions else versions;
  aliasesExpr = if builtins.isPath aliases then import aliases else aliases;
  genericExpr = if builtins.isPath genericBuilder then import genericBuilder else genericBuilder;

  aliases' = aliasesExpr { inherit lib; versions = versionsRaw; };
  versions' = if config.allowAliases then
      # Not sure if aliases or versions should have priority
      versionsRaw // aliases'
    else versionsRaw;

  # This also allows for additional attrs to be passed through besides version and src
  mkVersionArgs = { version, ... }@args: args // rec {
    # Some helpers commonly used to determine packaging behavior
    packageOlder = lib.versionOlder version;
    packageAtLeast = lib.versionAtLeast version;
    packageBetween = lower: higher: packageAtLeast lower && packageOlder higher;
    mkVersionPassthru = packageArgs: let
      versions = builtins.mapAttrs (_: v: mkPackage v packageArgs) versions';
    in versions // { inherit versions; };
  };

  # Re-call the generic builder with new version args, re-wrap with makeOverridable
  # to give it the same appearance as being called by callPackage
  mkPackage = version: lib.makeOverridable (genericExpr (mkVersionArgs version));
in
  # The partially applied function doesn't need to be called with makeOverridable
  # As callPackage will be wrapping this in makeOverridable as well
  genericExpr (mkVersionArgs (defaultSelector versions'))

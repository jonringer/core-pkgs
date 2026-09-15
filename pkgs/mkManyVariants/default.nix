{
  lib,
  config,

  # Allow for alias and variant exprs to reference things from pkgs
  callFromScope,
}:

{
  # Intended to be an attrset of { "<exposed variant>" = { variant = "<full variant>"; src = <path>; } }
  # or a file containing such variant information
  # Type: AttrSet AttrSet
  variants,

  # Additional aliases, as variant attrsets or strings naming raw variants.
  # Type: AttrSet AttrSet -> AttrSet AttrSet.
  aliases ? { ... }: { },

  # Package name used in EOL/removed messages (e.g. "linux")
  # Type: String
  name ? null,

  # Variants that have reached end-of-life. Still buildable but emit a warning.
  # Maps variant name to EOL date string, e.g. { v6_17 = "2026-08-01"; }
  # Requires `name` to be set.
  # Type: AttrSet String
  eol ? { },

  # Variants that have been fully removed. Accessing them throws an error.
  # Maps variant name to removal date string, e.g. { v6_13 = "2026-02-01"; }
  # Only honoured when `config.aliases.nixpkgs` is true.
  # Requires `name` to be set.
  # Type: AttrSet String
  removed ? { },

  # Selects one attribute from the variant set as the default.
  # Type: AttrSet a -> a
  defaultSelector,

  # Nix expression which takes variant and package args, and returns an attrset to pass to mkDerivation
  # Type: AttrSet -> AttrSet -> AttrSet
  genericBuilder,

  # This allows for each variant to be called with different inputs
  callPackage,
}:

# Some assertions as poor man's type checking
assert builtins.isFunction defaultSelector;
assert eol != { } -> name != null;
assert removed != { } -> name != null;

let
  importIfPath = x: if builtins.isPath x then import x else x;
  callIfFunction = x: if builtins.isFunction x then callFromScope x { } else x;

  variantsRaw = callIfFunction (importIfPath variants);
  aliasesExpr = importIfPath aliases;
  # Do not use callFromScope as the genericExpr should get called from package scope later
  genericExpr = importIfPath genericBuilder;

  aliasesRaw =
    if builtins.isFunction aliasesExpr then
      aliasesExpr {
        inherit lib;
        variants = variantsRaw;
      }
    else
      aliasesExpr;

  removedOverlay = lib.optionalAttrs config.aliases.nixpkgs (
    builtins.mapAttrs (
      n: date: throw "${name}.${n} is no longer available and was removed on ${date}."
    ) removed
  );

  addVariantPassthru =
    variants':
    variants'
    // builtins.mapAttrs (
      n: date:
      lib.warn "${name}.${n} is EOL as of ${date}. It is recommended to use a newer version."
        variants'.${n}
    ) eol
    // removedOverlay
    // {
      variants = variants';
    };

  mkSet =
    rawVariants:
    let
      aliases' = builtins.mapAttrs (_: v: if builtins.isString v then rawVariants.${v} else v) aliasesRaw;
      currentVariants = rawVariants // aliases';
      defaultVariantName = defaultSelector (
        builtins.mapAttrs (variantName: _: variantName) currentVariants
      );
      defaultVariant = currentVariants.${defaultVariantName};

      mkPackage =
        variant:
        let
          variantArgs =
            defaultVariant
            // variant
            // rec {
              packageOlder = lib.versionOlder variantArgs.version;
              packageAtLeast = lib.versionAtLeast variantArgs.version;
              packageBetween = lower: higher: packageAtLeast lower && packageOlder higher;
              mkVariantPassthru = _: variantPassthru;
            };
        in
        (callPackage (genericExpr variantArgs) { }).overrideAttrs (oldAttrs: {
          passthru =
            oldAttrs.passthru or { }
            // variantPassthru
            // {
              inherit variantArgs;
              extendVariants = extendVariantsFn rawVariants;
            };
        });

      rawPackages = builtins.mapAttrs (_: variant: mkPackage variant) rawVariants;
      aliasPackages = builtins.mapAttrs (
        _: alias: if builtins.isString alias then rawPackages.${alias} else mkPackage alias
      ) aliasesRaw;
      variantPassthru = addVariantPassthru (rawPackages // aliasPackages);
    in
    {
      inherit defaultVariantName variantPassthru;
    };

  # Add variants and return the extended default package.
  extendVariantsFn =
    baseRawVariants: extraVariants:
    defaultSelector (mkSet (baseRawVariants // extraVariants)).variantPassthru;

  topSet = mkSet variantsRaw;
  defaultPackage = defaultSelector topSet.variantPassthru;

  applyPackageArgs =
    packageArgs:
    let
      finalPackage = (defaultPackage.override packageArgs).overrideAttrs (oldAttrs: {
        passthru =
          oldAttrs.passthru
          // addVariantPassthru (
            oldAttrs.passthru.variants // { ${topSet.defaultVariantName} = finalPackage; }
          );
      });
    in
    finalPackage;
in
# The calling scope will apply `callPackage`, so we need to return the partially
# applied function
lib.setFunctionArgs applyPackageArgs (lib.functionArgs defaultPackage.override)

variantArgs:
if variantArgs.unwrapped or false then
  import ./unwrapped.nix variantArgs
else
  {
    callPackage,
    callFromScope,
    mkManyVariants,
    ...
  }@args:
  let
    binutilsUnwrapped = callPackage (callFromScope ./default.nix { wrap = false; }) { };
    inherit (variantArgs) variant;
    metadata = builtins.removeAttrs variantArgs [
      "packageOlder"
      "packageAtLeast"
      "packageBetween"
      "mkVariantPassthru"
    ];
    unwrapped =
      if variant == binutilsUnwrapped.variantArgs.variant then
        binutilsUnwrapped
      else
        binutilsUnwrapped.${variant} or null;
    bintools =
      if unwrapped != null && builtins.intersectAttrs metadata unwrapped.variantArgs == metadata then
        unwrapped
      else
        (binutilsUnwrapped.extendVariants { ${variant} = metadata; }).variants.${variant};
  in
  # Keep both wrappers on the same overridden tools and dependencies.
  (mkManyVariants {
    variants = ./wrappers.nix;
    aliases = { };
    defaultSelector = p: p.wrapped;
    genericBuilder = wrapperArgs: import ./wrapper.nix wrapperArgs;
    callPackage =
      builder: _:
      callPackage builder (
        {
          inherit bintools;
        }
        // builtins.removeAttrs args [
          "callPackage"
          "mkManyVariants"
          "callFromScope"
        ]
      );
  })
    { }

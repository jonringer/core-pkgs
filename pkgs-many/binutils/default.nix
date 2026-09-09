{
  mkManyVariants,
  callPackage,
  lib,
  stdenvNoCC,
  noSysDirs,
  wrap ? true,
  variant ? if stdenvNoCC.targetPlatform.isDarwin then "darwin" else "v2_44",
}:
mkManyVariants {
  variants = ./variants.nix;
  aliases = {
    real = "v2_44";
  };
  name = "binutils";
  defaultSelector = p: p.${variant};
  genericBuilder = if wrap then ./generic.nix else ./unwrapped.nix;
  callPackage =
    builder: args:
    callPackage builder (
      lib.optionalAttrs ((lib.functionArgs builder) ? noSysDirs) {
        noSysDirs = stdenvNoCC.targetPlatform != stdenvNoCC.hostPlatform || noSysDirs;
      }
      // args
    );
}

{ mkManyVariants, callPackage }:

mkManyVariants {
  variants = ./variants.nix;
  aliases = { };
  defaultSelector = (p: p.v1_11);
  genericBuilder = ./generic.nix;
  inherit callPackage;
}

{ mkManyVariants, callPackage }:

mkManyVariants {
  variants = ./variants.nix;
  aliases = { };
  name = "lttng-ust";
  defaultSelector = (p: p.v2_15);
  genericBuilder = ./generic.nix;
  inherit callPackage;
}

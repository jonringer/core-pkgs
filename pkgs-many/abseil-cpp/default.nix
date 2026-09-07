{ mkManyVariants, callPackage }:

mkManyVariants {
  variants = ./variants.nix;
  aliases = {
    # Compat aliases: old YYYYMM names -> new YYYYMMDD names
    v202401 = "v20240116";
    v202407 = "v20240722";
    v202508 = "v20250814";
  };
  defaultSelector = (p: p.v20250814);
  genericBuilder = ./generic.nix;
  inherit callPackage;
}

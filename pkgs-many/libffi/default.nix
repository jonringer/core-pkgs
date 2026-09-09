{
  mkManyVariants,
  callPackage,
  stdenv,
}:
mkManyVariants {
  variants = ./variants.nix;
  aliases = { };
  name = "libffi";
  removed = {
    v3_3 = "2026-09-09";
  };
  defaultSelector = p: if stdenv.hostPlatform.isDarwin then p.darwin else p.real;
  genericBuilder = ./generic.nix;
  inherit callPackage;
}

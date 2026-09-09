{
  mkManyVariants,
  callPackage,
  stdenv,
}:

mkManyVariants {
  variants = ./variants.nix;
  aliases = { };
  defaultSelector =
    p:
    if p ? libc then
      p.libc
    else if stdenv.hostPlatform.isDarwin then
      p.darwin
    else
      p.real;
  genericBuilder = ./generic.nix;
  inherit callPackage;
}

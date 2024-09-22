{ mkGenericPkg }:

mkGenericPkg {
  versions = ./versions.nix;
  aliases = ./aliases.nix;
  defaultSelector = (p: p.v3_3);
  genericBuilder = ./generic.nix;
}


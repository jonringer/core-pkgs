{
  lib,
  buildEnv,
  nix-prefetch-cvs ? null,
  nix-prefetch-darcs ? null,
  nix-prefetch-git,
  nix-prefetch-hg,
  nix-prefetch-svn,
  nix-prefetch-pijul,
}:
buildEnv {
  name = "nix-prefetch-scripts";

  paths =
    lib.optional (nix-prefetch-cvs != null) nix-prefetch-cvs
    ++ lib.optional (nix-prefetch-darcs != null) nix-prefetch-darcs
    ++ [
      nix-prefetch-git
      nix-prefetch-hg
      nix-prefetch-svn
      nix-prefetch-pijul
    ];

  meta = {
    description = "Collection of all the nix-prefetch-* scripts which may be used to obtain source hashes";
    platforms = lib.platforms.unix;
  };
}

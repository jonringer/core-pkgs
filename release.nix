/* This file defines the builds that constitute the Nixpkgs.
   Everything defined here ends up in the Nixpkgs channel.  Individual
   jobs can be tested by running:

   $ nix-build pkgs/top-level/release.nix -A <jobname>.<system>

   e.g.

   $ nix-build pkgs/top-level/release.nix -A coreutils.x86_64-linux
*/
{ pkgs ? { outPath = ./.; revCount = 1234; shortRev = "abcdef"; revision = "0000000000000000000000000000000000000000"; }
, system ? builtins.currentSystem
, officialRelease ? false
  # The platform doubles for which we build Nixpkgs.
, supportedSystems ? [
    "x86_64-linux"
    #"x86_64-darwin" "aarch64-linux" "aarch64-darwin"
  ]
  # The platform triples for which we build bootstrap tools.
, bootstrapConfigs ? [
    # "aarch64-apple-darwin"
    # "aarch64-unknown-linux-gnu"
    # "aarch64-unknown-linux-musl"
    # "i686-unknown-linux-gnu"
    # "x86_64-apple-darwin"
    # "x86_64-unknown-linux-gnu"
    # "x86_64-unknown-linux-musl"
    # we can uncomment that once our bootstrap tarballs are fixed
    #"x86_64-unknown-freebsd"
  ]
  # Strip most of attributes when evaluating to spare memory usage
, scrubJobs ? true
  # Attributes passed to nixpkgs. Don't build packages marked as unfree.
, pkgsArgs ? { config = {
    allowUnfree = false;
    inHydra = true;
  }; }

  # This flag, if set to true, will inhibit the use of `mapTestOn`
  # and `release-lib.packagePlatforms`.  Generally, it causes the
  # resulting tree of attributes to *not* have a ".${system}"
  # suffixed upon every job name like Hydra expects.
  #
  # This flag exists mainly for use by
  # pkgs/top-level/release-attrnames-superset.nix; see that file for
  # full details.  The exact behavior of this flag may change; it
  # should be considered an internal implementation detail of
  # pkgs/top-level/.
  #
, attrNamesOnly ? false
}:

let
  pins = import ./pins.nix;
  stdenv = import pins.stdenvRepo pkgsArgs;

  release-lib = stdenv.mkReleaseLib {
    inherit supportedSystems scrubJobs pkgsArgs system;
  };

  inherit (release-lib) mapTestOn pkgs;

  inherit (release-lib.lib)
    collect
    elem
    genAttrs
    hasInfix
    hasSuffix
    id
    isDerivation
    optionals
    ;

  inherit (release-lib.lib.attrsets) unionOfDisjoint;

  # supportDarwin = genAttrs [
  #   "x86_64"
  #   "aarch64"
  # ] (arch: elem "${arch}-darwin" supportedSystems);

  # TODO: stdenv, support
  nonPackageJobs = { };
  #   { tarball = import ./make-tarball.nix { inherit pkgs nixpkgs officialRelease; };

  #     release-checks = import ./nixpkgs-basic-release-checks.nix { inherit pkgs nixpkgs supportedSystems; };

  #     pkgs-lib-tests = import ../pkgs-lib/tests { inherit pkgs; };


  # Do not allow attribute collision between jobs inserted in
  # 'nonPackageAttrs' and jobs pulled in from 'pkgs'.
  # Conflicts usually cause silent job drops like in
  #   https://github.com/NixOS/nixpkgs/pull/182058
  jobs = let
    packagePlatforms = if attrNamesOnly then id else release-lib.packagePlatforms;
    packageJobs = {
      #haskell.compiler = packagePlatforms pkgs.haskell.compiler;
      #haskellPackages = packagePlatforms pkgs.haskellPackages;
      # Build selected packages (HLS) for multiple Haskell compilers to rebuild
      # the cache after a staging merge
      #haskell.packages = genAttrs [
      #  # TODO: share this list between release.nix and release-haskell.nix
      #  "ghc90"
      #  "ghc92"
      #  "ghc94"
      #  "ghc96"
      #  "ghc98"
      #] (compilerName: {
      #  inherit (packagePlatforms pkgs.haskell.packages.${compilerName})
      #    haskell-language-server;
      #});
      #idrisPackages = packagePlatforms pkgs.idrisPackages;
      #agdaPackages = packagePlatforms pkgs.agdaPackages;

      #pkgsLLVM.stdenv = [ "x86_64-linux" "aarch64-linux" ];
      #pkgsArocc.stdenv = [ "x86_64-linux" "aarch64-linux" ];
      #pkgsZig.stdenv = [ "x86_64-linux" "aarch64-linux" ];
      #pkgsMusl.stdenv = [ "x86_64-linux" "aarch64-linux" ];
      #pkgsStatic.stdenv = [ "x86_64-linux" "aarch64-linux" ];

      #tests = packagePlatforms pkgs.tests;

      # Language packages disabled in https://github.com/NixOS/nixpkgs/commit/ccd1029f58a3bb9eca32d81bf3f33cb4be25cc66

      #emacsPackages = packagePlatforms pkgs.emacsPackages;
      #rPackages = packagePlatforms pkgs.rPackages;
      #ocamlPackages = { };
      #perlPackages = { };

      #darwin = packagePlatforms pkgs.darwin // {
      #  xcode = {};
      #};
    };

    mapTestOn-packages =
      if attrNamesOnly
      then pkgs // packageJobs
      else mapTestOn ((packagePlatforms pkgs) // packageJobs);
  in
    unionOfDisjoint nonPackageJobs mapTestOn-packages;

in jobs

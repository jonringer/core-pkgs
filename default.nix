let
  #stdenvRepo = builtins.fetchGit {
  #  url = "https://github.com/jonringer/stdenv.git";
  #  rev = "415802fd971557fefc332d295527d61e304687e9";
  #};
  stdenvRepo = ../stdenv;

  lib = import (builtins.fetchGit {
    url = "https://github.com/jonringer/nix-lib.git";
    rev = "c19c816e39d14a60dd368d601aa9b389b09d0bbb";
  });

  inherit (lib.attrsets) mergeAttrsList mapAttrsToList;

  # TODO: Move to nix-lib if generic version proposal succeeds
  mkAutoCalledPolyPackageDir = baseDirectory:
  let
    namesForShard = lib.packageSets.mkNamesForDirectory baseDirectory;
    # This is defined up here in order to allow reuse of the value (it's kind of expensive to compute)
    # if the overlay has to be applied multiple times
    packageFiles = mergeAttrsList (mapAttrsToList namesForShard (builtins.readDir baseDirectory));
  in
  # TODO: Consider optimising this using `builtins.deepSeq packageFiles`,
  # which could free up the above thunks and reduce GC times.
  # Currently this would be hard to measure until we have more packages
  # and ideally https://github.com/NixOS/nix/pull/8895
  self: super:
    {
      _internalCallPolyFile = file: self.callPackage (import file { inherit (self) mkGenericPkg; }) { };
    }
    // builtins.mapAttrs
      (name: value: self._internalCallPolyFile value)
      packageFiles;

  polyPkgOverlay = mkAutoCalledPolyPackageDir ./polyPkgs;

  pkgsOverlay = lib.mkAutoCalledPackageDir ./pkgs;

  toplevelOverlay = import ./top-level.nix;
in

import stdenvRepo {
  overlays = [
    polyPkgOverlay
    pkgsOverlay
    toplevelOverlay
  ];
}

{
  overlays ? [ ]
, ...
}@args:

let
  stdenvRepo = builtins.fetchGit {
    url = "https://github.com/jonringer/stdenv.git";
    rev = "da940131d41b102d78014eb3084cef0d1033add9";
  };
  #stdenvRepo = ../stdenv;

  lib = import (builtins.fetchGit {
    url = "https://github.com/jonringer/nix-lib.git";
    rev = "c19c816e39d14a60dd368d601aa9b389b09d0bbb";
  });

  pkgsOverlay = lib.mkAutoCalledPackageDir ./pkgs;

  toplevelOverlay = import ./top-level.nix;

  filteredArgs = lib.filterAttrs [ "overlays" ] args;
in

import stdenvRepo ({
  overlays = [
    pkgsOverlay
    toplevelOverlay
  ] ++ overlays;
} // filteredArgs)

let
  stdenvRepo = builtins.fetchGit {
    url = "https://github.com/jonringer/stdenv.git";
    rev = "415802fd971557fefc332d295527d61e304687e9";
  };

  lib = import (builtins.fetchGit {
    url = "https://github.com/jonringer/nix-lib.git";
    rev = "c19c816e39d14a60dd368d601aa9b389b09d0bbb";
  });

  pkgsOverlay = lib.mkAutoCalledPackageDir ./pkgs;

  toplevelOverlay = import ./top-level.nix;
in

import stdenvRepo {
  overlays = [
    pkgsOverlay
    toplevelOverlay
  ];
}

{
  overlays ? [ ]
, ...
}@args:

let
  pins = import ./pins.nix;

  inherit (pins) lib;

  pkgsOverlay = lib.mkAutoCalledPackageDir ./pkgs;

  toplevelOverlay = import ./top-level.nix;

  filteredArgs = builtins.removeAttrs args [ "overlays" ];
in

import pins.stdenvRepo ({
  overlays = [
    pkgsOverlay
    toplevelOverlay
  ] ++ overlays;
} // filteredArgs)

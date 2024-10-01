{
  overlays ? [ ]
, ...
}@args:

let
  pins = import ./pins.nix;

  inherit (pins) lib;

  pkgsOverlay = lib.mkAutoCalledPackageDir ./pkgs;

  toplevelOverlay = import ./top-level.nix;

  filteredArgs = lib.filterAttrs [ "overlays" ] args;
in

import pins.stdenvRepo ({
  overlays = [
    pkgsOverlay
    toplevelOverlay
  ] ++ overlays;
} // filteredArgs)

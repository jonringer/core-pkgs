# Power Profiles Daemon — D-Bus daemon for user-selected power profiles
# Ported from nixpkgs/nixos/modules/services/hardware/power-profiles-daemon.nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.power-profiles-daemon;
in
{
  options.services.power-profiles-daemon = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable power-profiles-daemon, a D-Bus daemon that allows
        changing system behavior based upon user-selected power profiles.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.power-profiles-daemon or (throw "power-profiles-daemon package not available");
      defaultText = lib.literalExpression "pkgs.power-profiles-daemon";
      description = "The power-profiles-daemon package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    # TODO: systemd.packages not yet available in ekaOS
    # systemd.packages = [ cfg.package ];
  };
}

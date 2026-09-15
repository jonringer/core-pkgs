# Thunderbolt 3 device management daemon
# Ported from nixpkgs/nixos/modules/services/hardware/bolt.nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hardware.bolt;
in
{
  options.services.hardware.bolt = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable Bolt, a userspace daemon to enable
        security levels for Thunderbolt 3 on GNU/Linux.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bolt or (throw "bolt package not available");
      defaultText = lib.literalExpression "pkgs.bolt";
      description = "The bolt package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    # TODO: systemd.packages not yet available in ekaOS
    # systemd.packages = [ cfg.package ];
  };
}

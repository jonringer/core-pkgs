# Auto-detect battery and configure extended power management
{
  lib,
  config,
  ...
}:
let
  facterLib = import ./lib.nix lib;
  inherit (config.hardware.facter) report;
  cfg = config.hardware.facter.detected.power;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;
  isLaptop = config.hardware.facter.detected.laptop.enable;

  # Detect battery from facter report
  batteries = report.hardware.battery or [ ];
  hasBattery = builtins.length batteries > 0;

  # Detect swap for hibernate readiness
  swapDevices = report.swap or [ ];
  hasSwap = builtins.length swapDevices > 0;
in
{
  options.hardware.facter.detected.power = {
    battery.enable = lib.mkEnableOption "Facter battery detection" // {
      default = hasBattery || isLaptop;
      defaultText = "hardware dependent";
    };

    hibernate.enable = lib.mkEnableOption "Facter hibernate readiness" // {
      default = hasBattery && hasSwap && isBaremetal;
      defaultText = "hardware dependent";
    };
  };

  config = lib.mkIf config.hardware.facter.enable (
    lib.mkMerge [
      # Battery detected: optimize for power saving
      (lib.mkIf (cfg.battery.enable && isBaremetal) {
        # SCSI link power management for battery life
        power.scsiLinkPolicy = lib.mkDefault "med_power_with_dipm";

        # Enable power-profiles-daemon for D-Bus power profile switching
        # (used by Quickshell power profile switcher)
        services.power-profiles-daemon.enable = lib.mkDefault true;
      })
    ]
  );
}

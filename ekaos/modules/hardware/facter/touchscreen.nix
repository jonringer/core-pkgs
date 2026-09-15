# Auto-detect touchscreen input devices
{
  lib,
  config,
  ...
}:
let
  facterLib = import ./lib.nix lib;
  inherit (config.hardware.facter) report;
  cfg = config.hardware.facter.detected.touchscreen;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;

  # Touchscreen devices appear as input hardware in facter report
  # They may be in touchscreen-specific or generic input lists
  touchscreenDevices = report.hardware.touchscreen or [ ];

  # Also check for convertible/tablet chassis which implies touchscreen
  isConvertible = facterLib.isConvertibleChassis report;

  driverModules = facterLib.collectDrivers touchscreenDevices;
in
{
  options.hardware.facter.detected.touchscreen = {
    enable = lib.mkEnableOption "Facter touchscreen detection" // {
      default = (builtins.length touchscreenDevices > 0 || isConvertible) && isBaremetal;
      defaultText = "hardware dependent";
    };

    convertible.enable = lib.mkEnableOption "Facter convertible/tablet detection" // {
      default = isConvertible && isBaremetal;
      defaultText = "hardware dependent";
    };
  };

  config = lib.mkIf (config.hardware.facter.enable && cfg.enable) {
    # Load touchscreen driver modules
    boot.initrd.availableKernelModules = lib.unique driverModules;

    # Ensure libinput handles touch input (Wayland/Hyprland)
    # libinput is typically already configured but ensure modules are loaded
    boot.kernelModules = lib.mkIf cfg.convertible.enable [
      "hid-multitouch"
    ];
  };
}

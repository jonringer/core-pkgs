# Auto-detect gaming peripherals (gamepads, joysticks)
{
  lib,
  config,
  ...
}:
let
  facterLib = import ./lib.nix lib;
  inherit (config.hardware.facter) report;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;

  joystickDevices = report.hardware.joystick or [ ];
  hasJoystick = builtins.length joystickDevices > 0;

  driverModules = facterLib.collectDrivers joystickDevices;
in
{
  options.hardware.facter.detected.gaming = {
    enable = lib.mkEnableOption "Facter gaming peripheral detection" // {
      default = hasJoystick && isBaremetal;
      defaultText = "hardware dependent";
    };

    kernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.unique driverModules;
      defaultText = "hardware dependent";
      description = "Kernel modules for detected gaming peripherals.";
    };
  };

  config = lib.mkIf (config.hardware.facter.enable && config.hardware.facter.detected.gaming.enable) {
    # Load detected gamepad/joystick driver modules
    boot.kernelModules = config.hardware.facter.detected.gaming.kernelModules;

    # Common gamepad kernel modules that may not be in the facter report
    # but are needed for hot-plugged controllers
    boot.initrd.availableKernelModules = [
      "xpad" # Xbox controllers
      "hid-sony" # PlayStation controllers
      "hid-nintendo" # Nintendo controllers
    ];

    # TODO(corepkgs): Port steam-hardware udev rules for controller support
  };
}

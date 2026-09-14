# Auto-detect Thunderbolt/USB4 controllers
{
  lib,
  config,
  ...
}:
let
  inherit (config.hardware.facter) report;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;

  # Thunderbolt controllers appear as PCI devices
  # Intel Thunderbolt: vendor 0x8086 (32902), various device IDs
  # The facter report may list them under a dedicated category or as generic PCI
  thunderboltDevices = report.hardware.thunderbolt_controller or [ ];

  hasThunderbolt = builtins.length thunderboltDevices > 0;
in
{
  options.hardware.facter.detected.thunderbolt.enable =
    lib.mkEnableOption "Facter Thunderbolt/USB4 detection"
    // {
      default = hasThunderbolt && isBaremetal;
      defaultText = "hardware dependent";
    };

  config =
    lib.mkIf (config.hardware.facter.enable && config.hardware.facter.detected.thunderbolt.enable)
      {
        # Load thunderbolt kernel module for device authorization
        boot.kernelModules = [ "thunderbolt" ];

        # Enable boltd for Thunderbolt device authorization
        services.hardware.bolt.enable = lib.mkDefault true;
      };
}

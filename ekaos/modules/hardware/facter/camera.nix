# Auto-detect Intel IPU6 camera hardware and configure platform
{
  lib,
  config,
  ...
}:
let
  facterLib = import ./lib.nix lib;
  inherit (config.hardware.facter) report;

  # Intel IPU6 PCI device IDs per CPU generation
  # Vendor: Intel (0x8086 = 32902)
  tigerLakeId = 39449; # 0x9a19
  alderLakeId = 18013; # 0x465d
  raptorLakeId = 42845; # 0xa75d
  meteorLakeId = 32025; # 0x7d19

  allIpu6Ids = [
    tigerLakeId
    alderLakeId
    raptorLakeId
    meteorLakeId
  ];

  multimediaDevices = report.hardware.multimedia_controller or [ ];

  # Find the matching IPU6 device
  ipu6Device = lib.findFirst (
    {
      vendor ? { },
      device ? { },
      ...
    }:
    (vendor.value or 0) == 32902 && builtins.elem (device.value or 0) allIpu6Ids
  ) null multimediaDevices;

  hasIpu6 = ipu6Device != null;

  # Determine platform from the detected device ID
  detectedDeviceId = if hasIpu6 then (ipu6Device.device.value or 0) else 0;

  detectedPlatform =
    if detectedDeviceId == tigerLakeId then
      "ipu6"
    else if detectedDeviceId == alderLakeId || detectedDeviceId == raptorLakeId then
      "ipu6ep"
    else if detectedDeviceId == meteorLakeId then
      "ipu6epmtl"
    else
      "ipu6";
in
{
  options.hardware.facter.detected.camera.ipu6 = {
    enable = lib.mkEnableOption "Facter Intel IPU6 camera detection" // {
      default = hasIpu6;
      defaultText = "hardware dependent";
    };

    platform = lib.mkOption {
      type = lib.types.enum [
        "ipu6"
        "ipu6ep"
        "ipu6epmtl"
      ];
      default = detectedPlatform;
      defaultText = "hardware dependent";
      description = "Auto-detected IPU6 platform variant based on CPU generation.";
    };
  };

  config =
    lib.mkIf (config.hardware.facter.enable && config.hardware.facter.detected.camera.ipu6.enable)
      {
        hardware.ipu6.enable = lib.mkDefault true;
        hardware.ipu6.platform = lib.mkDefault config.hardware.facter.detected.camera.ipu6.platform;
      };
}

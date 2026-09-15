# Auto-detect Intel IPU6/IPU7 camera hardware and configure platform
{
  lib,
  config,
  ...
}:
let
  facterLib = import ./lib.nix lib;
  inherit (config.hardware.facter) report;

  # Vendor: Intel (0x8086 = 32902)
  intelVendorId = 32902;

  # Intel IPU6 PCI device IDs per CPU generation
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

  # Intel IPU7 PCI device IDs
  lunarLakeId = 25693; # 0x645d
  arrowLakeId = 45149; # 0xb05d

  allIpu7Ids = [
    lunarLakeId
    arrowLakeId
  ];

  multimediaDevices = report.hardware.multimedia_controller or [ ];

  # Find Intel multimedia devices
  findIntelDevice =
    ids:
    lib.findFirst (
      {
        vendor ? { },
        device ? { },
        ...
      }:
      (vendor.value or 0) == intelVendorId && builtins.elem (device.value or 0) ids
    ) null multimediaDevices;

  # IPU6 detection
  ipu6Device = findIntelDevice allIpu6Ids;
  hasIpu6 = ipu6Device != null;
  ipu6DeviceId = if hasIpu6 then (ipu6Device.device.value or 0) else 0;

  detectedIpu6Platform =
    if ipu6DeviceId == tigerLakeId then
      "ipu6"
    else if ipu6DeviceId == alderLakeId || ipu6DeviceId == raptorLakeId then
      "ipu6ep"
    else if ipu6DeviceId == meteorLakeId then
      "ipu6epmtl"
    else
      "ipu6";

  # IPU7 detection
  ipu7Device = findIntelDevice allIpu7Ids;
  hasIpu7 = ipu7Device != null;
  ipu7DeviceId = if hasIpu7 then (ipu7Device.device.value or 0) else 0;

  detectedIpu7Platform = if ipu7DeviceId == arrowLakeId then "ipu75xa" else "ipu7x";
in
{
  options.hardware.facter.detected.camera = {
    ipu6 = {
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
        default = detectedIpu6Platform;
        defaultText = "hardware dependent";
        description = "Auto-detected IPU6 platform variant based on CPU generation.";
      };
    };

    ipu7 = {
      enable = lib.mkEnableOption "Facter Intel IPU7 camera detection" // {
        default = hasIpu7;
        defaultText = "hardware dependent";
      };

      platform = lib.mkOption {
        type = lib.types.enum [
          "ipu7x"
          "ipu75xa"
        ];
        default = detectedIpu7Platform;
        defaultText = "hardware dependent";
        description = "Auto-detected IPU7 platform variant.";
      };
    };
  };

  config = lib.mkIf config.hardware.facter.enable (
    lib.mkMerge [
      (lib.mkIf config.hardware.facter.detected.camera.ipu6.enable {
        hardware.ipu6.enable = lib.mkDefault true;
        hardware.ipu6.platform = lib.mkDefault config.hardware.facter.detected.camera.ipu6.platform;
      })

      (lib.mkIf config.hardware.facter.detected.camera.ipu7.enable {
        hardware.ipu7.enable = lib.mkDefault true;
        hardware.ipu7.platform = lib.mkDefault config.hardware.facter.detected.camera.ipu7.platform;
      })
    ]
  );
}

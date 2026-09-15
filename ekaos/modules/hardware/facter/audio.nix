# Auto-detect audio hardware and configure sound device support
{
  lib,
  config,
  ...
}:
let
  facterLib = import ./lib.nix lib;
  inherit (config.hardware.facter) report;
  cfg = config.hardware.facter.detected.audio;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;

  soundDevices = report.hardware.sound or [ ];
  driverModules = facterLib.collectDrivers soundDevices;

  # Detect Intel SOF (Sound Open Firmware) audio by driver module names
  hasSofDriver = builtins.any (
    m: lib.hasPrefix "snd_sof" m || lib.hasPrefix "snd-sof" m
  ) driverModules;

  # Detect Intel HDA audio
  hasHdaDriver = builtins.any (
    m: lib.hasPrefix "snd_hda" m || lib.hasPrefix "snd-hda" m
  ) driverModules;
in
{
  options.hardware.facter.detected.audio = {
    enable = lib.mkEnableOption "Facter audio hardware detection" // {
      default = builtins.length soundDevices > 0;
      defaultText = "hardware dependent";
    };

    kernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.unique driverModules;
      defaultText = "hardware dependent";
      description = "Kernel modules for detected audio hardware.";
    };

    sof.enable = lib.mkEnableOption "Facter Intel SOF audio detection" // {
      default = hasSofDriver;
      defaultText = "hardware dependent";
    };

    hda.enable = lib.mkEnableOption "Facter Intel HDA audio detection" // {
      default = hasHdaDriver;
      defaultText = "hardware dependent";
    };
  };

  config = lib.mkIf config.hardware.facter.enable (
    lib.mkMerge [
      # Load audio driver modules
      (lib.mkIf cfg.enable {
        boot.initrd.availableKernelModules = cfg.kernelModules;
      })

      # Intel SOF audio: load additional SOF-specific modules
      (lib.mkIf (cfg.enable && cfg.sof.enable) {
        boot.kernelModules = [
          "snd_sof"
          "snd_sof_pci"
          "snd_sof_intel_hda_common"
        ];
      })

      # Intel HDA audio
      (lib.mkIf (cfg.enable && cfg.hda.enable) {
        boot.kernelModules = [
          "snd_hda_intel"
        ];
      })
    ]
  );
}

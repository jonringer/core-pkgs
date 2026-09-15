# Auto-configure GPU vendor-specific graphics defaults
{
  lib,
  config,
  ...
}:
let
  facterLib = import ./lib.nix lib;
  inherit (config.hardware.facter) report;
  cfg = config.hardware.facter.detected.gpu;
in
{
  options.hardware.facter.detected.gpu = {
    amd.enable = lib.mkEnableOption "Facter AMD GPU detection" // {
      default = facterLib.hasAmdGpu report;
      defaultText = "hardware dependent";
    };

    intel.enable = lib.mkEnableOption "Facter Intel GPU detection" // {
      default = facterLib.hasIntelGpu report;
      defaultText = "hardware dependent";
    };

    nvidia.enable = lib.mkEnableOption "Facter NVIDIA GPU detection" // {
      default = facterLib.hasNvidiaGpu report;
      defaultText = "hardware dependent";
    };
  };

  config = lib.mkIf config.hardware.facter.enable (
    lib.mkMerge [
      # AMD GPU: enable graphics with 32-bit support, early KMS for display at boot
      (lib.mkIf cfg.amd.enable {
        hardware.graphics.enable = lib.mkDefault true;
        hardware.graphics.enable32Bit = lib.mkDefault true;
        boot.initrd.kernelModules = [ "amdgpu" ];
      })

      # Intel GPU: enable graphics stack, load i915 early for display at boot
      (lib.mkIf cfg.intel.enable {
        hardware.graphics.enable = lib.mkDefault true;
        boot.initrd.kernelModules = [ "i915" ];
      })

      # NVIDIA GPU: enable graphics stack
      # Driver configuration is handled by hardware.nvidia (via facter/nvidia.nix)
      (lib.mkIf cfg.nvidia.enable {
        hardware.graphics.enable = lib.mkDefault true;
      })
    ]
  );
}

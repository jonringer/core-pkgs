# Auto-configure NVIDIA GPU: driver options, generation detection, and PRIME
{
  lib,
  config,
  ...
}:
let
  facterLib = import ./lib.nix lib;
  inherit (config.hardware.facter) report;
  cfg = config.hardware.facter.detected.nvidia;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;

  gpus = report.hardware.graphics_card or [ ];

  # Extract NVIDIA GPUs from facter report
  nvidiaGpus = builtins.filter (
    {
      vendor ? { },
      ...
    }:
    (vendor.value or 0) == 4318 # 0x10de
  ) gpus;

  # Extract non-NVIDIA GPUs (for hybrid detection)
  otherGpus = builtins.filter (
    {
      vendor ? { },
      ...
    }:
    let
      vid = vendor.value or 0;
    in
    vid != 4318 && (vid == 32902 || vid == 4098) # Intel or AMD
  ) gpus;

  hasNvidia = builtins.length nvidiaGpus > 0;
  hasOtherGpu = builtins.length otherGpus > 0;
  isHybrid = hasNvidia && hasOtherGpu;

  # Extract PCI bus ID from slot field in format "PCI:X:Y:Z"
  slotToBusId =
    slot:
    let
      # slot format is typically "0000:XX:YY.Z"
      parts = lib.splitString ":" slot;
      hasDomain = builtins.length parts >= 3;
      # Drop the domain prefix if present
      busStr = if hasDomain then builtins.elemAt parts 1 else builtins.elemAt parts 0;
      rest = if hasDomain then builtins.elemAt parts 2 else builtins.elemAt parts 1;
      devFn = lib.splitString "." rest;
      devStr = builtins.elemAt devFn 0;
      fnStr = if builtins.length devFn > 1 then builtins.elemAt devFn 1 else "0";
    in
    "PCI:${builtins.toString (facterLib.hexToInt busStr)}:${builtins.toString (facterLib.hexToInt devStr)}:${fnStr}";

  # Simple hex string to int for bus IDs (handles 1-2 hex digits)
  hexToInt =
    s:
    let
      hexChars = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };
      chars = lib.stringToCharacters (lib.toLower s);
    in
    lib.foldl' (acc: c: acc * 16 + (hexChars.${c} or 0)) 0 chars;

  # Extract bus ID from a GPU entry
  gpuBusId =
    gpu:
    let
      slot = gpu.slot or "";
      parts = lib.splitString ":" slot;
      hasDomain = builtins.length parts >= 3;
      busStr = if hasDomain then builtins.elemAt parts 1 else builtins.elemAt parts 0;
      rest = if hasDomain then builtins.elemAt parts 2 else builtins.elemAt parts 1;
      devFn = lib.splitString "." rest;
      devStr = builtins.elemAt devFn 0;
      fnStr = if builtins.length devFn > 1 then builtins.elemAt devFn 1 else "0";
    in
    if slot == "" then
      ""
    else
      "PCI:${builtins.toString (hexToInt busStr)}:${builtins.toString (hexToInt devStr)}:${fnStr}";

  nvidiaBusId = if builtins.length nvidiaGpus > 0 then gpuBusId (builtins.head nvidiaGpus) else "";

  # Determine iGPU bus ID and type
  iGpu = if builtins.length otherGpus > 0 then builtins.head otherGpus else null;
  iGpuBusId = if iGpu != null then gpuBusId iGpu else "";
  iGpuIsIntel = iGpu != null && (iGpu.vendor.value or 0) == 32902;
  iGpuIsAmd = iGpu != null && (iGpu.vendor.value or 0) == 4098;
in
{
  options.hardware.facter.detected.nvidia = {
    enable = lib.mkEnableOption "Facter NVIDIA GPU auto-configuration" // {
      default = hasNvidia && isBaremetal;
      defaultText = "hardware dependent";
    };

    hybrid.enable = lib.mkEnableOption "Facter hybrid GPU (PRIME) detection" // {
      default = isHybrid && isBaremetal;
      defaultText = "hardware dependent";
    };

    busId = lib.mkOption {
      type = lib.types.str;
      default = nvidiaBusId;
      defaultText = "hardware dependent";
      description = "PCI bus ID of the NVIDIA GPU (auto-detected from facter report).";
    };

    iGpuBusId = lib.mkOption {
      type = lib.types.str;
      default = iGpuBusId;
      defaultText = "hardware dependent";
      description = "PCI bus ID of the integrated GPU (auto-detected from facter report).";
    };

    iGpuVendor = lib.mkOption {
      type = lib.types.enum [
        "intel"
        "amd"
        "none"
      ];
      default =
        if iGpuIsIntel then
          "intel"
        else if iGpuIsAmd then
          "amd"
        else
          "none";
      defaultText = "hardware dependent";
      description = "Vendor of the integrated GPU.";
    };
  };

  config = lib.mkIf config.hardware.facter.enable (
    lib.mkMerge [
      # Enable the NVIDIA hardware module with auto-detected settings
      (lib.mkIf cfg.enable {
        hardware.nvidia.enable = lib.mkDefault true;
        hardware.nvidia.prime.nvidiaBusId = lib.mkDefault cfg.busId;
      })

      # Hybrid GPU: auto-configure PRIME offload with detected bus IDs
      (lib.mkIf cfg.hybrid.enable {
        hardware.nvidia.prime.offload.enable = lib.mkDefault true;
        hardware.nvidia.prime.intelBusId = lib.mkIf (cfg.iGpuVendor == "intel") (
          lib.mkDefault cfg.iGpuBusId
        );
        hardware.nvidia.prime.amdgpuBusId = lib.mkIf (cfg.iGpuVendor == "amd") (
          lib.mkDefault cfg.iGpuBusId
        );
      })
    ]
  );
}

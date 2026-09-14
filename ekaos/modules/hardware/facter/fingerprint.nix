# Auto-detect fingerprint readers and enable fprintd
{
  lib,
  config,
  ...
}:
let
  inherit (config.hardware.facter) report;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;

  fingerprintDevices = report.hardware.fingerprint_reader or [ ];

  # Known fingerprint reader USB vendor IDs
  # Goodix (0x27c6=10182), Synaptics/WBDI (0x06cb=1739), Elan (0x04f3=1267),
  # AuthenTec (0x147e=5246), Validity/Synaptics (0x138a=5002)
  knownVendors = [
    10182
    1739
    1267
    5246
    5002
  ];

  hasFingerprint = builtins.length fingerprintDevices > 0;

  # Check if detected device is from a known vendor (for confidence)
  hasKnownDevice = builtins.any (
    {
      vendor ? { },
      ...
    }:
    builtins.elem (vendor.value or 0) knownVendors
  ) fingerprintDevices;
in
{
  options.hardware.facter.detected.fingerprint.enable =
    lib.mkEnableOption "Facter fingerprint reader detection"
    // {
      default = hasFingerprint && isBaremetal;
      defaultText = "hardware dependent";
    };

  config =
    lib.mkIf (config.hardware.facter.enable && config.hardware.facter.detected.fingerprint.enable)
      {
        services.fprintd.enable = lib.mkDefault true;
      };
}

# Auto-detect scanner hardware for SANE enablement
{
  lib,
  config,
  ...
}:
let
  inherit (config.hardware.facter) report;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;

  scannerDevices = report.hardware.scanner or [ ];
  hasScanner = builtins.length scannerDevices > 0;
in
{
  options.hardware.facter.detected.scanner.enable = lib.mkEnableOption "Facter scanner detection" // {
    default = hasScanner && isBaremetal;
    defaultText = "hardware dependent";
  };

  config =
    lib.mkIf (config.hardware.facter.enable && config.hardware.facter.detected.scanner.enable)
      {
        # TODO(corepkgs): Port hardware.sane module (sane-backends), then enable:
        # hardware.sane.enable = lib.mkDefault true;
      };
}

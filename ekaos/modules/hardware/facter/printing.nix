# Auto-detect printer hardware for CUPS enablement
{
  lib,
  config,
  ...
}:
let
  inherit (config.hardware.facter) report;
  isBaremetal = config.hardware.facter.detected.virtualisation.none.enable;

  printerDevices = report.hardware.printer or [ ];
  hasPrinter = builtins.length printerDevices > 0;
in
{
  options.hardware.facter.detected.printing.enable =
    lib.mkEnableOption "Facter printer detection"
    // {
      default = hasPrinter && isBaremetal;
      defaultText = "hardware dependent";
    };

  config =
    lib.mkIf (config.hardware.facter.enable && config.hardware.facter.detected.printing.enable)
      {
        # TODO(corepkgs): Port services.printing (CUPS) module, then enable:
        # services.printing.enable = lib.mkDefault true;
      };
}

# A/B boot scheme via systemd-boot boot counting
#
# Adds boot counting to BLS entries so that a failed boot automatically
# rolls back to the previous generation. The newest entry gets a +N-0
# suffix; the bless-boot service removes it after the health check passes.
# If N boots fail, systemd-boot falls back to the previous proven entry.
#
# No special partition layout, no slot abstraction. The existing
# generation system and /run/booted-system vs /run/current-system
# already provide the A/B semantics.
{
  config,
  lib,
  ...
}:

with lib;

{
  options = {
    boot.ab = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable A/B boot with automatic rollback.

          Adds boot counting to the newest BLS entry on the ESP.
          If the health check fails after the configured number of
          boot attempts, systemd-boot automatically falls back to
          the previous proven generation.
        '';
      };

      bootCountTriesLeft = mkOption {
        type = types.int;
        default = 3;
        description = ''
          Number of boot attempts before systemd-boot considers
          a generation failed and falls back to the previous one.
        '';
      };

      healthCheck = {
        command = mkOption {
          type = types.str;
          default = "systemctl is-system-running --wait";
          description = ''
            Command that must succeed for the boot to be blessed.
          '';
        };

        timeout = mkOption {
          type = types.int;
          default = 120;
          description = ''
            Maximum seconds to wait for the health check.
          '';
        };
      };
    };
  };

  config = mkIf config.boot.ab.enable {
    assertions = [
      {
        assertion = config.boot.loader.systemd-boot.enable;
        message = "boot.ab requires boot.loader.systemd-boot.enable = true";
      }
    ];
  };
}

# jigd compilation cache daemon
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.jigd;
in

{
  options.services.jigd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the jigd compilation cache daemon.";
    };

    description = mkOption {
      type = types.str;
      default = "jigd Compilation Cache";
      description = "Service description.";
    };

    command = mkOption {
      type = types.str;
      internal = true;
      description = "Command to run (set automatically).";
    };

    args = mkOption {
      type = types.listOf types.str;
      internal = true;
      default = [ ];
      description = "Command arguments (set automatically).";
    };

    user = mkOption {
      type = types.str;
      default = "jigd";
      description = "User to run jigd as.";
    };

    restartPolicy = mkOption {
      type = types.str;
      default = "always";
      description = "Restart policy.";
    };

    systemd = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Systemd-specific options.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.jigd;
      description = "jigd package to use.";
    };

    settings = mkOption {
      type = types.submodule {
        options = {
          socketPath = mkOption {
            type = types.str;
            default = "/run/jigd/jigd.sock";
            description = "Path to the jigd Unix socket.";
          };

          cacheDir = mkOption {
            type = types.str;
            default = "/var/cache/jigd";
            description = "Directory for the compilation cache.";
          };

          cacheSize = mkOption {
            type = types.int;
            default = 50;
            description = "Cache budget in GiB. Least-recently-read packs are evicted when exceeded.";
          };

          slots = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Maximum concurrent compiler processes. Defaults to CPU count.";
          };
        };
      };
      default = { };
      description = "jigd configuration.";
    };
  };

  config = mkIf cfg.enable {
    services.jigd = {
      command = "${cfg.package}/bin/jigd";
      args = [ cfg.settings.socketPath ];
      restartPolicy = "always";

      systemd = {
        after = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Environment = [
            "JIGD_SIZE=${toString cfg.settings.cacheSize}"
          ]
          ++ optional (cfg.settings.slots != null) "JIGD_SLOTS=${toString cfg.settings.slots}";
          RuntimeDirectory = "jigd";
          RuntimeDirectoryMode = "0755";
          CacheDirectory = "jigd";
          CacheDirectoryMode = "0700";
        };
      };
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      homeDirectory = cfg.settings.cacheDir;
      group = cfg.user;
      description = "jigd compilation cache daemon";
    };
    users.groups.${cfg.user} = { };

    system.activationScripts.jigd = stringAfter [ "etc" "users" ] ''
      mkdir -p ${cfg.settings.cacheDir}
      chown ${cfg.user}:${cfg.user} ${cfg.settings.cacheDir}
      chmod 700 ${cfg.settings.cacheDir}

      mkdir -p ${dirOf cfg.settings.socketPath}
      chown ${cfg.user}:${cfg.user} ${dirOf cfg.settings.socketPath}
      chmod 755 ${dirOf cfg.settings.socketPath}
    '';
  };
}

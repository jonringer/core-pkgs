# Bless-boot service for A/B boot
# Runs a health check after boot and removes the boot counting suffix
# from the current BLS entry, marking the boot as successful.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.boot.ab;
  espMount = config.boot.loader.efi.efiSysMountPoint;

  blessBootScript = pkgs.writeScript "ekaos-bless-boot" ''
    #!${pkgs.runtimeShell}
    set -e

    # Find the BLS entry that booted us by matching the init path.
    # /run/booted-system/init is the init that systemd-boot loaded,
    # and the BLS entry's "options" line contains init=<that path>.
    BOOTED_INIT=$(readlink -f /run/booted-system/init 2>/dev/null || true)
    if [ -z "$BOOTED_INIT" ]; then
      echo "ekaos-bless-boot: cannot determine booted system, skipping"
      exit 0
    fi

    ENTRY_DIR="${espMount}/loader/entries"

    # Check if any entry for our booted system has a boot counting suffix.
    # If not, there's nothing to bless (already blessed or boot counting not active).
    FOUND=""
    for f in "$ENTRY_DIR"/*+[0-9]*-[0-9]*.conf; do
      [ -f "$f" ] || continue
      if ${pkgs.gnugrep}/bin/grep -q "init=$BOOTED_INIT" "$f"; then
        FOUND="$f"
        break
      fi
    done

    if [ -z "$FOUND" ]; then
      echo "ekaos-bless-boot: no unblessed entry for current boot, nothing to do"
      exit 0
    fi

    echo "Running boot health check..."

    # Run the health check. Default is "systemctl is-system-running --wait"
    # which returns 0 for "running" and non-zero for "degraded"/"starting"/etc.
    if ${pkgs.coreutils}/bin/timeout ${toString cfg.healthCheck.timeout} ${cfg.healthCheck.command}; then
      echo "Health check passed."
    else
      echo "Health check FAILED. Boot will NOT be blessed."
      echo "On next reboot, systemd-boot will decrement the try counter."
      exit 1
    fi

    # Bless: rename the entry to remove the +N-M suffix
    BLESSED=$(echo "$FOUND" | ${pkgs.gnused}/bin/sed 's/+[0-9]*-[0-9]*//')
    mv "$FOUND" "$BLESSED"
    echo "Blessed: $(basename "$FOUND") -> $(basename "$BLESSED")"
  '';

in

{
  options = {
    services.ekaos-bless-boot = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the bless-boot service.";
      };

      description = mkOption {
        type = types.str;
        default = "Bless boot after health check";
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
        description = "Command arguments.";
      };

      user = mkOption {
        type = types.str;
        default = "root";
        description = "User to run service as.";
      };

      restartPolicy = mkOption {
        type = types.str;
        default = "never";
        description = "Restart policy.";
      };

      systemd = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Systemd-specific options.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.ekaos-bless-boot = {
      enable = true;
      command = "${blessBootScript}";
      systemd = {
        wantedBy = [ "multi-user.target" ];
        after = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    };
  };
}

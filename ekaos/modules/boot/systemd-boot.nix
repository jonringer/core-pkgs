# systemd-boot UEFI boot loader configuration
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.boot.loader.systemd-boot;

  abCfg = config.boot.ab;

  # Wrap the systemd-boot-builder.py script with substitutions
  systemdBootBuilder = pkgs.substituteAll {
    src = ../../lib/systemd-boot-builder.py;
    isExecutable = true;

    inherit (pkgs) python3;
    systemd = config.systemd.package;
    nix = pkgs.nix;
    timeout = cfg.timeout;
    editor = if cfg.editor then "True" else "False";
    configurationLimit = cfg.configurationLimit;
    inherit (cfg) consoleMode graceful;

    efiSysMountPoint = config.boot.loader.efi.efiSysMountPoint;
    bootMountPoint = config.boot.loader.efi.efiSysMountPoint;
    canTouchEfiVariables = if config.boot.loader.efi.canTouchEfiVariables then "1" else "0";
    efiType = builtins.toJSON config.boot.loader.efi.type;
    nixosDir = "EFI/ekaos";
    distroName = "ekaos";
    rebootForBitlocker = "0";
    storeDir = builtins.storeDir;

    # A/B boot substitutions
    abEnabled = if abCfg.enable then "1" else "0";
    abBootCountTries = toString abCfg.bootCountTriesLeft;
  };

in

{
  options = {
    # Compatibility options for nixpkgs make-disk-image.nix
    boot.loader.grub.enable = mkOption {
      type = types.bool;
      default = false;
      description = "GRUB is not supported in ekaos. Use systemd-boot instead.";
    };

    boot.loader.limine.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Limine is not supported in ekaos. Use systemd-boot instead.";
    };

    boot.loader.systemd-boot = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable the systemd-boot (formerly gummiboot) UEFI boot loader.

          This boot loader is simple and lightweight, suitable for UEFI systems.
        '';
      };

      sortKey = mkOption {
        type = types.str;
        default = "ekaos";
        description = ''
          Sort key for boot entries.

          Controls the order in which entries appear in the boot menu.
        '';
      };

      timeout = mkOption {
        type = types.nullOr types.int;
        default = 5;
        description = ''
          Boot menu timeout in seconds.

          null means wait indefinitely for user input.
        '';
      };

      editor = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to allow editing boot parameters in the boot menu.
        '';
      };

      configurationLimit = mkOption {
        type = types.int;
        default = 20;
        description = ''
          Maximum number of boot configurations to keep.

          Older configurations will be automatically cleaned up.
        '';
      };

      consoleMode = mkOption {
        type = types.enum [
          "auto"
          "max"
          "keep"
        ];
        default = "keep";
        description = ''
          Console mode for the boot loader.

          - auto: Set to maximum available
          - max: Same as auto
          - keep: Keep current mode
        '';
      };

      graceful = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Continue even if some operations fail.

          Useful for troubleshooting boot loader issues.
        '';
      };

      memtest86.enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to add a memtest86+ entry to the systemd-boot menu.

          Requires the memtest86plus package.
        '';
      };

      extraInstallCommands = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Additional commands to run after installing the boot loader.
        '';
      };
    };

    boot.loader.efi = {
      canTouchEfiVariables = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether the system can modify EFI boot variables.

          Needed for proper boot loader installation.
        '';
      };

      efiSysMountPoint = mkOption {
        type = types.str;
        default = "/boot";
        description = ''
          Where the EFI System Partition (ESP) is mounted.
        '';
      };

      type = mkOption {
        type = types.listOf (
          types.enum [
            "efi"
            "uki"
          ]
        );
        default = [ "efi" ];
        description = ''
          Boot entry types to install.

          - "efi": Traditional BLS Type #1 entries with separate kernel/initrd files
            and .conf entry files. This is the default and current behavior.
          - "uki": Unified Kernel Image — a single .efi PE binary per generation
            bundling the EFI stub, kernel, initrd, and command line. Discovered
            by systemd-boot via Type #2 autodiscovery in /EFI/Linux/.

          Both can be specified simultaneously for dual boot entries.
        '';
      };
    };

    system.build.installBootLoader = mkOption {
      type = types.package;
      internal = true;
      description = "Script to install the boot loader.";
    };
  };

  config = mkIf cfg.enable {
    # Build the boot loader installer script
    system.build.installBootLoader = pkgs.writeScript "install-systemd-boot.sh" ''
      #!${pkgs.runtimeShell}
      set -e

      # The systemd-boot-builder.py script expects the system path as argument
      ${systemdBootBuilder} "$@"

      ${cfg.extraInstallCommands}
    '';

    # Ensure systemd-boot extensions are added to bootspec
    # (This will be used by systemd-boot-builder.py)
    boot.loader.systemd-boot.sortKey = mkDefault "ekaos";

    # Add systemd-boot to system packages for bootctl command
    environment.systemPackages = [ config.systemd.package ];

    # Install memtest86+ boot entry
    boot.loader.systemd-boot.extraInstallCommands = mkIf cfg.memtest86.enable ''
      ${
        let
          memtest = pkgs.memtest86plus or (throw "memtest86plus package not available");
        in
        ''
          # Copy memtest86+ binary
          mkdir -p ${config.boot.loader.efi.efiSysMountPoint}/EFI/memtest86
          cp ${memtest}/memtest.efi ${config.boot.loader.efi.efiSysMountPoint}/EFI/memtest86/memtest.efi 2>/dev/null || true

          # Create boot entry
          mkdir -p ${config.boot.loader.efi.efiSysMountPoint}/loader/entries
          cat > ${config.boot.loader.efi.efiSysMountPoint}/loader/entries/memtest86.conf <<MEMEOF
          title   Memtest86+
          efi     /EFI/memtest86/memtest.efi
          MEMEOF
        ''
      }
    '';
  };
}

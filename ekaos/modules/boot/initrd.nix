# Initramfs (initrd) configuration for ekaos
# Provides stage-1 boot support for advanced scenarios

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.boot.initrd;

in

{
  options = {
    boot.initrd = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable initramfs (initial ramdisk).

          When enabled, the system boots through a two-stage process:
          1. Stage-1: Initramfs mounts root and loads modules
          2. Stage-2: Real init (systemd) starts

          Required for:
          - Encrypted root filesystem (LUKS)
          - LVM root filesystem
          - Software RAID
          - Network root filesystem (iSCSI, NFS)
          - Non-standard root filesystem types
        '';
      };

      availableKernelModules = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "ahci"
          "xhci_pci"
          "nvme"
          "usb_storage"
          "sd_mod"
        ];
        description = ''
          Kernel modules to include in the initramfs.

          These modules are loaded during stage-1 boot to support
          hardware needed to access the root filesystem.

          Common modules:
          - ahci, ata_piix: SATA controllers
          - nvme: NVMe drives
          - xhci_pci, ehci_pci: USB controllers
          - usb_storage: USB storage devices
          - sd_mod: SCSI disk support
          - virtio_blk, virtio_pci: VirtIO (for VMs)
        '';
      };

      kernelModules = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "dm-crypt"
          "dm-mod"
        ];
        description = ''
          Additional kernel modules to load in initramfs.

          Loaded after availableKernelModules.
        '';
      };

      luks.devices = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              device = mkOption {
                type = types.str;
                example = "/dev/sda2";
                description = "Path to the encrypted device.";
              };

              name = mkOption {
                type = types.str;
                default = "";
                description = "Name of the decrypted device mapper entry.";
              };

              keyFile = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "/root/luks-key";
                description = "Path to key file for automatic unlocking.";
              };

              allowDiscards = mkOption {
                type = types.bool;
                default = false;
                description = "Enable TRIM/discard support for SSDs.";
              };
            };
          }
        );
        default = { };
        description = ''
          LUKS encrypted devices to unlock during stage-1.

          Each device will be unlocked and made available as
          /dev/mapper/<name> before mounting root.
        '';
        example = literalExpression ''
          {
            root = {
              device = "/dev/sda2";
              name = "cryptroot";
              allowDiscards = true;
            };
          }
        '';
      };

      supportedFilesystems = mkOption {
        type = types.listOf types.str;
        default = [
          "ext4"
          "vfat"
        ];
        example = [
          "ext4"
          "btrfs"
          "xfs"
          "vfat"
        ];
        description = ''
          Filesystem types to support in initramfs.

          Tools for these filesystems will be included.
        '';
      };

      extraUtilsCommands = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Additional commands to run when building initramfs utilities.

          Use this to copy additional binaries into the initramfs.
        '';
        example = ''
          copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
        '';
      };

      preLVMCommands = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Shell commands to run in stage-1 before LVM activation.
        '';
      };

      postDeviceCommands = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Shell commands to run after device initialization.
        '';
      };

      postMountCommands = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Shell commands to run after mounting root filesystem.
        '';
      };

      compressor = mkOption {
        type = types.str;
        default = "gzip";
        example = "zstd";
        description = ''
          Compression program for the initramfs.

          Options: gzip, bzip2, xz, zstd, lz4, lzop
        '';
      };

      includeDefaultModules = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Include a default set of kernel modules for common hardware.

          Includes modules for SATA, USB, NVMe, and common filesystems.
        '';
      };

    };

    system.build.initrd = mkOption {
      type = types.package;
      internal = true;
      description = "The initramfs image.";
    };

    system.build.initialRamdisk = mkOption {
      type = types.package;
      internal = true;
      description = "Alias for system.build.initrd.";
    };
  };

  config = mkIf cfg.enable {
    # Default kernel modules for common hardware
    boot.initrd.availableKernelModules = mkIf cfg.includeDefaultModules [
      # SATA/PATA
      "ahci"
      "ata_piix"
      "sata_nv"
      "sata_via"

      # NVMe
      "nvme"

      # USB
      "xhci_pci"
      "ehci_pci"
      "uhci_hcd"
      "usb_storage"
      "sd_mod"

      # VirtIO (for VMs)
      "virtio_blk"
      "virtio_pci"
      "virtio_scsi"
    ];

    # Add filesystem-specific modules and LUKS modules
    boot.initrd.kernelModules = mkMerge [
      # Filesystem modules
      (mkIf (elem "ext4" cfg.supportedFilesystems) [ "ext4" ])
      (mkIf (elem "btrfs" cfg.supportedFilesystems) [ "btrfs" ])
      (mkIf (elem "xfs" cfg.supportedFilesystems) [ "xfs" ])
      (mkIf (elem "vfat" cfg.supportedFilesystems) [
        "vfat"
        "nls_cp437"
        "nls_iso8859-1"
      ])

      # LUKS modules if any LUKS devices are configured
      (mkIf (cfg.luks.devices != { }) [
        "dm-crypt"
        "dm-mod"
        "aes"
        "sha256"
        "sha512"
      ])
    ];

    # Build the initrd
    system.build.initrd = import ../../lib/make-initrd.nix {
      inherit (config.boot.initrd)
        availableKernelModules
        kernelModules
        compressor
        extraUtilsCommands
        preLVMCommands
        postDeviceCommands
        postMountCommands
        luks
        supportedFilesystems
        ;
      inherit pkgs lib;
      kernelPackages = config.boot.kernelPackages;
    };

    # Alias
    system.build.initialRamdisk = config.system.build.initrd;
  };
}

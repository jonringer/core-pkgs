# ISO image module for ekaos
#
# Defines isoImage.* options and produces a UEFI-bootable ISO image
# containing the system closure in a squashfs archive.
#
# The live boot mechanism:
# 1. UEFI firmware loads systemd-boot from the ISO's EFI partition
# 2. systemd-boot loads the kernel and initrd
# 3. The initrd finds the ISO by volume label, mounts the squashfs,
#    and sets up an overlayfs for writable /nix/store
# 4. switch_root hands off to the stage-2 init
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.isoImage;

  kernelPath = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
  initrdPath = "${config.system.build.initialRamdisk}/initrd";

  # Build the EFI boot image — a FAT filesystem containing systemd-boot,
  # the kernel, and the initrd.
  loaderConf = pkgs.writeText "loader.conf" ''
    timeout ${toString cfg.bootTimeout}
    default ekaos.conf
    editor no
  '';

  bootEntry = pkgs.writeText "ekaos.conf" ''
    title   ${cfg.bootMenuLabel}
    linux   /EFI/ekaos/vmlinuz
    initrd  /EFI/ekaos/initrd
    options init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
  '';

  efiDir = pkgs.runCommand "efi-directory" { } ''
    mkdir -p $out/EFI/BOOT $out/EFI/ekaos $out/loader/entries

    # Copy the systemd-boot EFI binary
    bootBinary="${config.systemd.package}/lib/systemd/boot/efi/systemd-boot${pkgs.stdenv.hostPlatform.efiArch}.efi"

    if [ -f "$bootBinary" ]; then
      cp "$bootBinary" "$out/EFI/BOOT/BOOT${lib.toUpper pkgs.stdenv.hostPlatform.efiArch}.EFI"
    else
      echo "error: systemd-boot EFI binary not found at $bootBinary" >&2
      exit 1
    fi

    # Copy kernel and initrd
    cp ${kernelPath} $out/EFI/ekaos/vmlinuz
    cp ${initrdPath} $out/EFI/ekaos/initrd

    # Loader configuration
    cp ${loaderConf} $out/loader/loader.conf
    cp ${bootEntry} $out/loader/entries/ekaos.conf
  '';

  # Create the EFI boot image (FAT filesystem for El Torito boot)
  efiImg =
    pkgs.runCommand "efi-image"
      {
        nativeBuildInputs = [
          pkgs.dosfstools
          pkgs.mtools
        ];
      }
      ''
        # Copy EFI directory contents
        mkdir ./contents && cd ./contents
        cp -r ${efiDir}/* .

        # Rewrite dates for reproducibility
        find . -exec touch --date=2000-01-01 {} +

        # Calculate image size: 110% of content size, rounded up to 1 MiB blocks
        usage_size=$(du -sb --apparent-size . | cut -f1)
        image_size=$(( (usage_size * 110 / 100 + 1048575) / 1048576 * 1048576 ))
        # Minimum 4 MiB for FAT overhead
        if [ "$image_size" -lt 4194304 ]; then
          image_size=4194304
        fi

        truncate --size=$image_size "$out"
        mkfs.vfat -i 12345678 -n EFIBOOT "$out"

        # Populate the FAT image
        for d in $(find . -type d | sort); do
          mmd -i "$out" "::/$d" 2>/dev/null || true
        done
        for f in $(find . -type f | sort); do
          mcopy -i "$out" "$f" "::/$f"
        done

        # Verify
        fsck.vfat -vn "$out"
      '';

in

{
  options.isoImage = {
    enable = mkEnableOption "ISO image generation for this system";

    volumeID = mkOption {
      type = types.str;
      default = "EKAOS";
      description = ''
        ISO 9660 volume identifier. Used by the initrd to find and mount
        the ISO filesystem during boot. Maximum 32 characters.
      '';
    };

    edition = mkOption {
      type = types.str;
      default = "";
      description = "Edition string included in the ISO file name.";
    };

    squashfsCompression = mkOption {
      type = types.nullOr types.str;
      default = "zstd -Xcompression-level 6";
      description = ''
        Compression settings for the squashfs nix store image.
        Set to null to disable compression.
      '';
    };

    compressImage = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to compress the final ISO image with zstd.";
    };

    bootTimeout = mkOption {
      type = types.int;
      default = 10;
      description = "Boot menu timeout in seconds.";
    };

    bootMenuLabel = mkOption {
      type = types.str;
      default = "EkaOS ${config.system.ekaos.version}";
      description = "Label shown in the boot menu.";
    };

    contents = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            source = mkOption {
              type = types.path;
              description = "Source file or directory.";
            };
            target = mkOption {
              type = types.str;
              description = "Target path on the ISO.";
            };
          };
        }
      );
      default = [ ];
      description = "Additional files and directories to include on the ISO.";
    };

    storeContents = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        Additional store paths to include in the squashfs nix store image.
        The system closure is always included.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = stringLength cfg.volumeID <= 32;
        message = "isoImage.volumeID must be at most 32 characters (got ${toString (stringLength cfg.volumeID)}).";
      }
    ];

    # Enable initrd for the live boot sequence
    boot.initrd.enable = true;

    # Kernel modules needed for ISO live boot
    boot.initrd.availableKernelModules = [
      "iso9660"
      "sr_mod" # CD/DVD drive
      "uas" # USB attached SCSI
      "usb_storage"
    ];

    boot.initrd.kernelModules = [
      "squashfs"
      "loop"
      "overlay"
    ];

    # Filesystem support in initrd
    boot.initrd.supportedFilesystems = [ "vfat" ];

    # Tell the initrd how to find the root — pass the ISO label via kernel params
    boot.kernelParams = [
      "boot.shell_on_fail"
      "root=live:LABEL=${cfg.volumeID}"
    ];

    # Disable the standard boot loader installer (not needed for ISOs)
    boot.loader.systemd-boot.enable = mkForce false;

    # Extra initrd utilities needed for live boot
    boot.initrd.extraUtilsCommands = ''
      # Copy losetup for loop device management
      copy_bin_and_libs ${pkgs.util-linux}/bin/losetup
      copy_bin_and_libs ${pkgs.util-linux}/bin/blkid
      copy_bin_and_libs ${pkgs.util-linux}/bin/findfs
    '';

    # Live boot logic: find the ISO, mount squashfs, set up overlayfs
    boot.initrd.postDeviceCommands = ''
      echo "ekaos live boot: searching for ISO filesystem..."

      # Wait for the ISO device to appear (USB/CD may be slow)
      for i in $(seq 1 30); do
        ISO_DEV=$(blkid -L "${cfg.volumeID}" 2>/dev/null || true)
        if [ -n "$ISO_DEV" ]; then
          break
        fi
        echo "  waiting for device with label ${cfg.volumeID}... ($i/30)"
        sleep 1
      done

      if [ -z "$ISO_DEV" ]; then
        echo "error: could not find device with label '${cfg.volumeID}'"
        echo "Available block devices:"
        blkid || true
        echo "Dropping to emergency shell..."
        exec /bin/sh
      fi

      echo "Found ISO at $ISO_DEV"

      # Mount the ISO filesystem
      mkdir -p /mnt-iso
      mount -t iso9660 -o ro "$ISO_DEV" /mnt-iso

      # Verify the squashfs image exists
      if [ ! -f /mnt-iso/nix-store.squashfs ]; then
        echo "error: /nix-store.squashfs not found on ISO"
        echo "ISO contents:"
        ls -la /mnt-iso/
        exec /bin/sh
      fi

      # Set up the root filesystem as tmpfs
      mount -t tmpfs -o mode=0755 tmpfs /mnt-root

      # Create the nix store overlay structure
      mkdir -p /mnt-root/nix/.ro-store
      mkdir -p /mnt-root/nix/.rw-store/store
      mkdir -p /mnt-root/nix/.rw-store/work
      mkdir -p /mnt-root/nix/store

      # Mount the squashfs as the read-only lower layer
      mount -t squashfs -o loop,ro /mnt-iso/nix-store.squashfs /mnt-root/nix/.ro-store

      # Mount a tmpfs for the writable upper layer
      mount -t tmpfs -o mode=0755 tmpfs /mnt-root/nix/.rw-store

      # Re-create work/store dirs after tmpfs mount
      mkdir -p /mnt-root/nix/.rw-store/store
      mkdir -p /mnt-root/nix/.rw-store/work

      # Set up the overlay
      mount -t overlay overlay \
        -o lowerdir=/mnt-root/nix/.ro-store,upperdir=/mnt-root/nix/.rw-store/store,workdir=/mnt-root/nix/.rw-store/work \
        /mnt-root/nix/store

      # Create essential directories in the tmpfs root
      mkdir -p /mnt-root/{bin,etc,home,proc,run,sys,dev,tmp,var,usr}
      chmod 1777 /mnt-root/tmp

      # Bind the ISO so it stays accessible after switch_root
      mkdir -p /mnt-root/iso
      mount --move /mnt-iso /mnt-root/iso

      echo "ekaos live boot: nix store overlay ready"
    '';

    # Skip the normal root mount logic — we handle it in postDeviceCommands.
    # Override postMountCommands to handle the switch_root preparation.
    boot.initrd.postMountCommands = ''
      echo "ekaos live boot: preparing switch_root..."
    '';

    # System closure goes into the squashfs
    isoImage.storeContents = [ config.system.build.toplevel ];

    # Register nix store paths from the squashfs after boot.
    # Uses an activation script since it must run very early, before
    # the nix daemon starts.
    system.activationScripts.register-iso-nix-paths = stringAfter [ "etc" ] ''
      if [ -f /nix/store/nix-path-registration ]; then
        ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration
      fi

      # Create system profile
      touch /etc/EKAOS
      ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
    '';

    # Build the ISO image
    system.build.isoImage =
      let
        isoBaseName = "ekaos${
          optionalString (cfg.edition != "") "-${cfg.edition}"
        }-${config.system.ekaos.version}-${pkgs.stdenv.hostPlatform.system}";
      in
      import ../../lib/make-iso9660-image.nix {
        inherit pkgs lib;
        inherit (cfg) compressImage;
        isoName = "${isoBaseName}.iso";
        inherit (cfg) volumeID;
        squashfsContents = cfg.storeContents;
        squashfsCompression = cfg.squashfsCompression;
        efiBootImage = efiImg;
        contents = [
          {
            source = efiDir;
            target = "/EFI";
          }
          {
            source = efiImg;
            target = "/EFI/efiboot.img";
          }
          {
            source = pkgs.writeText "version" config.system.ekaos.version;
            target = "/version.txt";
          }
        ]
        ++ cfg.contents;
      };
  };
}

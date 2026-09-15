# Initramfs (initrd) builder for ekaos
# Creates a minimal initial ramdisk for stage-1 boot

{
  pkgs,
  lib,
  kernelPackages,
  availableKernelModules ? [ ],
  kernelModules ? [ ],
  compressor ? "gzip",
  extraUtilsCommands ? "",
  preLVMCommands ? "",
  postDeviceCommands ? "",
  postMountCommands ? "",
  luks ? {
    devices = { };
  },
  supportedFilesystems ? [
    "ext4"
    "vfat"
  ],
}:

let
  inherit (lib) concatStringsSep optionalString;

  # Compression commands
  compressorExe =
    {
      gzip = "${pkgs.gzip}/bin/gzip";
      bzip2 = "${pkgs.bzip2}/bin/bzip2";
      xz = "${pkgs.xz}/bin/xz";
      zstd = "${pkgs.zstd}/bin/zstd";
      lz4 = "${pkgs.lz4}/bin/lz4";
      lzop = "${pkgs.lzop}/bin/lzop";
    }
    .${compressor} or "${pkgs.gzip}/bin/gzip";

  # All kernel modules to include
  allModules = availableKernelModules ++ kernelModules;

  # Build minimal utilities for initramfs
  extraUtils =
    pkgs.runCommand "initrd-utils"
      {
        nativeBuildInputs = [ pkgs.buildPackages.nukeReferences ];
        allowedReferences = [ "out" ];
      }
      ''
        set +o pipefail

        mkdir -p $out/bin $out/lib

        # Copy busybox (provides most basic utilities)
        cp ${pkgs.busybox}/bin/busybox $out/bin/

        # Create busybox symlinks
        for cmd in sh ash mount umount mkdir mknod switch_root cat cp mv rm ln chmod chown \
                   sleep echo test true false kill pidof ps grep sed awk cut sort uniq wc \
                   find xargs basename dirname readlink realpath pwd which env; do
          ln -sf busybox $out/bin/$cmd
        done

        # Copy modprobe for kernel module loading
        copy_bin_and_libs() {
          local BIN="$1"
          cp "$BIN" $out/bin/

          # Copy shared libraries
          local LIBS=$(${pkgs.buildPackages.patchelf}/bin/patchelf --print-needed "$BIN" 2>/dev/null || true)
          for lib in $LIBS; do
            local libPath=$(${pkgs.buildPackages.patchelf}/bin/patchelf --print-rpath "$BIN" 2>/dev/null | tr ':' '\n' | \
              xargs -I{} find {} -name "$lib" 2>/dev/null | head -1)
            if [ -n "$libPath" ] && [ -f "$libPath" ]; then
              cp "$libPath" $out/lib/ 2>/dev/null || true
            fi
          done
        }

        copy_bin_and_libs ${pkgs.kmod}/bin/modprobe
        ln -sf modprobe $out/bin/insmod
        ln -sf modprobe $out/bin/lsmod
        ln -sf modprobe $out/bin/rmmod

        # Copy mount utilities
        copy_bin_and_libs ${pkgs.util-linux}/bin/mount
        copy_bin_and_libs ${pkgs.util-linux}/bin/umount

        # Copy filesystem tools
        ${optionalString (lib.elem "ext4" supportedFilesystems) ''
          copy_bin_and_libs ${pkgs.e2fsprogs}/bin/e2fsck
          ln -sf e2fsck $out/bin/fsck.ext4
        ''}

        ${optionalString (lib.elem "vfat" supportedFilesystems) ''
          copy_bin_and_libs ${pkgs.dosfstools}/bin/fsck.vfat
        ''}

        # Copy LUKS utilities if needed
        ${optionalString (luks.devices != { }) ''
          copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
        ''}

        # Extra utilities from configuration
        ${extraUtilsCommands}

        # Strip binaries and nuke references
        find $out/bin -type f -exec ${pkgs.buildPackages.patchelf}/bin/patchelf --set-rpath $out/lib {} \; || true
        find $out/bin -type f -exec strip -s {} \; 2>/dev/null || true
        find $out/lib -type f -exec strip -s {} \; 2>/dev/null || true

        nuke-refs $out/bin/* $out/lib/* || true
      '';

  # Stage-1 init script
  bootStage1 = pkgs.writeScript "init" ''
    #!${extraUtils}/bin/sh
    set -e

    echo "ekaos stage-1 init starting..."

    # Set up basic environment
    export PATH=${extraUtils}/bin
    export LD_LIBRARY_PATH=${extraUtils}/lib

    # Mount essential filesystems
    mount -t proc proc /proc
    mount -t sysfs sysfs /sys
    mount -t devtmpfs devtmpfs /dev
    mount -t tmpfs tmpfs /run

    # Create device nodes
    mkdir -p /dev/pts /dev/shm
    mount -t devpts devpts /dev/pts
    mount -t tmpfs tmpfs /dev/shm

    echo "Loading kernel modules..."
    # Load kernel modules
    ${concatStringsSep "\n" (map (mod: "modprobe ${mod} || true") allModules)}

    # Wait for devices to settle
    sleep 1

    ${preLVMCommands}

    # Unlock LUKS devices
    ${concatStringsSep "\n" (
      lib.mapAttrsToList (name: dev: ''
        echo "Unlocking LUKS device ${dev.device}..."
        ${
          if dev.keyFile != null then
            "cryptsetup luksOpen ${dev.device} ${
              if dev.name != "" then dev.name else name
            } --key-file=${dev.keyFile} ${optionalString dev.allowDiscards "--allow-discards"}"
          else
            "cryptsetup luksOpen ${dev.device} ${
              if dev.name != "" then dev.name else name
            } ${optionalString dev.allowDiscards "--allow-discards"}"
        }
      '') luks.devices
    )}

    ${postDeviceCommands}

    # Find and mount root filesystem
    echo "Mounting root filesystem..."
    mkdir -p /mnt-root

    # Standard boot: use /dev/vda2 or LUKS root
    ROOT_DEVICE="/dev/vda2"
    if [ -e /dev/mapper/cryptroot ]; then
      ROOT_DEVICE="/dev/mapper/cryptroot"
    fi

    mount "$ROOT_DEVICE" /mnt-root || {
      echo "Failed to mount root filesystem"
      echo "Available block devices:"
      ls -l /dev/vd* /dev/sd* /dev/mapper/* /dev/disk/by-partlabel/* 2>/dev/null || true
      /bin/sh  # Drop to shell for debugging
    }

    ${postMountCommands}

    echo "Switching to real root..."
    # Move mounts to new root
    mount --move /proc /mnt-root/proc
    mount --move /sys /mnt-root/sys
    mount --move /dev /mnt-root/dev
    mount --move /run /mnt-root/run

    # Switch to real root and exec stage-2 init
    exec switch_root /mnt-root /init
  '';

  # Kernel modules directory — aggregateModules takes a list of module
  # packages (kernel, out-of-tree drivers, etc.) and runs depmod.
  modulesTree = pkgs.aggregateModules [ kernelPackages.kernel ];

in

kernelPackages.kernel.makeInitrd {
  contents = [
    {
      object = bootStage1;
      symlink = "/init";
    }
    {
      object = extraUtils;
      symlink = "/bin";
    }
    {
      object = "${extraUtils}/lib";
      symlink = "/lib";
    }
    {
      object = modulesTree;
      symlink = "/lib/modules";
    }
  ];

  compressor = compressorExe;
}

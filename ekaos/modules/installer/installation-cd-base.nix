# Base configuration for EkaOS live/installation media
#
# Provides the foundation for bootable ISO images:
# - ISO image generation enabled
# - Initrd for live boot
# - Live user with passwordless sudo
# - Networking and essential tools
#
# This module is imported directly by ISO configurations —
# it is NOT registered in module-list.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  # iso-image.nix is registered in module-list.nix and loaded for all
  # system evaluations (disabled by default).  We only need to flip the
  # enable flag here.
  isoImage.enable = true;

  # Boot configuration
  boot.initrd.enable = true;
  boot.initrd.compressor = "zstd";

  # Broad hardware support for installation media
  boot.initrd.includeDefaultModules = true;
  boot.initrd.availableKernelModules = [
    # Additional storage controllers
    "sata_nv"
    "sata_via"
    "sata_sis"
    "pata_via"
    "ahci"
    "nvme"
    # USB
    "xhci_pci"
    "ehci_pci"
    "uhci_hcd"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sr_mod"
    # VirtIO
    "virtio_blk"
    "virtio_pci"
    "virtio_scsi"
    "virtio_net"
  ];

  # Filesystem support
  boot.initrd.supportedFilesystems = [
    "ext4"
    "btrfs"
    "xfs"
    "vfat"
  ];

  # Kernel parameters for live boot
  boot.kernelParams = [
    "boot.shell_on_fail"
  ];

  # Networking
  networking.networkmanager.enable = mkDefault true;

  # Live user
  users.users.nixos = {
    isNormalUser = true;
    initialPassword = "";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];
    description = "Live User";
  };

  # Allow root login without password
  users.users.root.initialPassword = mkDefault "";

  # Passwordless sudo for the live environment
  security.sudo.enable = mkDefault true;
  security.sudo.wheelNeedsPassword = false;

  # Polkit — allow wheel group to do anything (needed for installers)
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Essential packages available in corepkgs
  environment.systemPackages = with pkgs; [
    # Partitioning and filesystem tools
    parted
    gptfdisk
    e2fsprogs
    dosfstools
    cryptsetup

    # Hardware inspection
    pciutils

    # Editors
    nano

    # Utilities
    jq
    unzip
    zip
    rsync
    socat
  ];

  # Git for convenience
  programs.git.enable = mkDefault true;

  # Enable SSH for headless installs
  services.openssh.enable = mkDefault true;

  # Tell the Nix evaluator to garbage collect aggressively in low-memory
  # environments that don't have swap.
  environment.variables.GC_INITIAL_HEAP_SIZE = "1M";

  # Allow overcommit — installation processes fork heavily.
  boot.kernel.sysctl."vm.overcommit_memory" = mkDefault "1";
}

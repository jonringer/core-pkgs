# Intel IPU6/MIPI camera hardware configuration
# Simplified from nixpkgs for ekaos
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.ipu6;
in
{
  options.hardware.ipu6 = {
    enable = lib.mkEnableOption "support for Intel IPU6/MIPI cameras";

    platform = lib.mkOption {
      type = lib.types.enum [
        "ipu6"
        "ipu6ep"
        "ipu6epmtl"
      ];
      description = ''
        Choose the IPU version for your hardware platform.

        Use `ipu6` for Tiger Lake, `ipu6ep` for Alder Lake or Raptor Lake,
        and `ipu6epmtl` for Meteor Lake.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Load IPU6 kernel drivers (upstream since kernel 6.10, but still needs
    # out-of-tree i2c sensors and intel-ipu6-psys kernel driver)
    boot.extraModulePackages = [ config.boot.kernelPackages.ipu6-drivers ];

    # IPU6 firmware and Intel Vision Sensing Controller firmware
    hardware.firmware = [
      pkgs.ipu6-camera-bins
      pkgs.ivsc-firmware
    ];

    # Restrict IPU6 raw nodes and media controller to root.
    # TAG-="uaccess" blocks logind ACL grants at login.
    services.udev.extraRules = ''
      SUBSYSTEM=="intel-ipu6-psys", MODE="0660", GROUP="video"
      SUBSYSTEM=="media", DRIVERS=="intel-ipu6", MODE="0600", GROUP="root", TAG-="uaccess"
      SUBSYSTEM=="video4linux", DRIVERS=="intel-ipu6", MODE="0600", GROUP="root", TAG-="uaccess"
    '';

    # ipu6-camera-hal writes AIQ tuning data and debug logs here
    tmpfiles.rules = [
      {
        type = "directory";
        path = "/run/camera";
        mode = "0755";
        user = "root";
        group = "video";
      }
    ];

    # Install the platform-specific camera HAL
    environment.systemPackages =
      let
        hal =
          {
            "ipu6" = pkgs.ipu6-camera-hal;
            "ipu6ep" = pkgs.ipu6ep-camera-hal;
            "ipu6epmtl" = pkgs.ipu6epmtl-camera-hal;
          }
          .${cfg.platform};
      in
      [ hal ];

    # TODO(corepkgs): Port v4l2-relayd and configure v4l2loopback relay
    # for presenting IPU6 camera as a standard V4L2 device.
    # The full nixpkgs module uses services.v4l2-relayd.instances.ipu6
    # with icamerasrc-{ipu6,ipu6ep,ipu6epmtl} GStreamer plugins.

    # TODO(corepkgs): Port WirePlumber configuration to disable raw IPU6
    # nodes so applications only see the v4l2loopback relay device.
  };
}

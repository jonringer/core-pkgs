# NVIDIA GPU hardware configuration
# Simplified from nixpkgs for ekaos (Wayland-only, no X server)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.nvidia;
  nvidia_x11 = cfg.package;

  inherit (config.boot.kernelPackages) nvidiaPackages;

  useOpenModules = cfg.open == true;

  pCfg = cfg.prime;
  primeEnabled = pCfg.offload.enable || pCfg.sync.enable || pCfg.reverseSync.enable;
  busIDType = lib.types.strMatching "([[:print:]]+:[0-9]{1,3}(@[0-9]{1,10})?:[0-9]{1,2}:[0-9])?";
in
{
  options.hardware.nvidia = {
    enable = lib.mkEnableOption "NVIDIA proprietary driver support";

    package = lib.mkOption {
      type = lib.types.package;
      default = nvidiaPackages.${cfg.branch};
      defaultText = lib.literalExpression "config.boot.kernelPackages.nvidiaPackages.\${config.hardware.nvidia.branch}";
      description = ''
        The NVIDIA driver package to use.

        Prefer using {option}`hardware.nvidia.branch` when possible.
        If you set this, pick a package from
        `config.boot.kernelPackages.nvidiaPackages` so the driver build
        matches your configured kernel.
      '';
    };

    branch = lib.mkOption {
      type =
        (lib.types.enum (builtins.attrNames (lib.filterAttrs (_: lib.isDerivation) nvidiaPackages)))
        // {
          description = "one of the available NVIDIA driver branches";
        };
      default = "stable";
      example = "production";
      description = ''
        The branch of the NVIDIA driver to use.

        Common branches: stable, production, latest, beta, vulkan_beta,
        legacy_535, legacy_470.
      '';
    };

    open = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = if lib.versionOlder nvidia_x11.version "560" then false else null;
      defaultText = lib.literalExpression ''
        if lib.versionOlder config.hardware.nvidia.package.version "560" then false else null
      '';
      example = true;
      description = ''
        Whether to use the open source NVIDIA kernel module.

        Recommended for Turing or later GPUs (RTX series, GTX 16xx).
        Use closed source modules for older GPUs.
      '';
    };

    modesetting.enable = lib.mkEnableOption "kernel modesetting for the NVIDIA driver" // {
      default = lib.versionAtLeast cfg.package.version "535";
      defaultText = lib.literalExpression ''
        lib.versionAtLeast config.hardware.nvidia.package.version "535"
      '';
    };

    gsp.enable = lib.mkEnableOption "GPU System Processor (GSP) firmware" // {
      default = useOpenModules || lib.versionAtLeast nvidia_x11.version "555";
      defaultText = lib.literalExpression ''
        config.hardware.nvidia.open == true || lib.versionAtLeast config.hardware.nvidia.package.version "555"
      '';
    };

    powerManagement = {
      enable = lib.mkEnableOption ''
        NVIDIA power management through systemd (suspend/resume support)
      '';

      finegrained = lib.mkEnableOption ''
        fine-grained power management (PCI-Express Runtime D3).
        Requires PRIME offload to be enabled. Powers down the dGPU when idle
      '';
    };

    dynamicBoost.enable = lib.mkEnableOption ''
      Dynamic Boost to balance power between CPU and GPU on supported laptops
    '';

    prime = {
      nvidiaBusId = lib.mkOption {
        type = busIDType;
        default = "";
        example = "PCI:1:0:0";
        description = "Bus ID of the NVIDIA GPU.";
      };

      intelBusId = lib.mkOption {
        type = busIDType;
        default = "";
        example = "PCI:0:2:0";
        description = "Bus ID of the Intel integrated GPU.";
      };

      amdgpuBusId = lib.mkOption {
        type = busIDType;
        default = "";
        example = "PCI:4:0:0";
        description = "Bus ID of the AMD integrated GPU.";
      };

      offload.enable = lib.mkEnableOption ''
        NVIDIA PRIME render offload. The dGPU renders only when explicitly
        requested via environment variables. Battery-friendly default for laptops
      '';

      sync.enable = lib.mkEnableOption ''
        NVIDIA PRIME sync mode. The dGPU is always on and handles all rendering.
        Outputs through the iGPU display outputs without a MUX
      '';

      reverseSync.enable = lib.mkEnableOption ''
        NVIDIA PRIME reverse sync. The iGPU handles rendering while the dGPU
        provides additional display outputs
      '';

      allowExternalGpu = lib.mkEnableOption "external GPU (eGPU) support via Thunderbolt";
    };

    nvidiaSettings = lib.mkEnableOption "nvidia-settings GUI configuration tool" // {
      default = true;
    };

    nvidiaPersistenced = lib.mkEnableOption ''
      nvidia-persistenced daemon to keep GPUs awake in headless mode
    '';
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Core driver configuration
      {
        assertions = [
          {
            assertion = cfg.open != null;
            message = ''
              You must set hardware.nvidia.open on NVIDIA driver versions >= 560.
              Use true for Turing+ GPUs (RTX, GTX 16xx), false for older GPUs.
            '';
          }
          {
            assertion = !useOpenModules || (nvidia_x11 ? open);
            message = "The selected NVIDIA package does not provide open kernel modules.";
          }
          {
            assertion = !useOpenModules || cfg.gsp.enable;
            message = "GSP cannot be disabled when using the open source kernel driver.";
          }
          {
            assertion =
              primeEnabled -> pCfg.nvidiaBusId != "" && (pCfg.intelBusId != "" || pCfg.amdgpuBusId != "");
            message = "When NVIDIA PRIME is enabled, GPU bus IDs must be configured.";
          }
          {
            assertion = !(pCfg.sync.enable && pCfg.offload.enable);
            message = "PRIME Sync and Offload cannot both be enabled.";
          }
          {
            assertion = !(pCfg.sync.enable && pCfg.reverseSync.enable);
            message = "PRIME Sync and Reverse Sync cannot both be enabled.";
          }
          {
            assertion = !(pCfg.sync.enable && cfg.powerManagement.finegrained);
            message = "Sync mode precludes powering down the NVIDIA GPU.";
          }
          {
            assertion = cfg.powerManagement.finegrained -> pCfg.offload.enable;
            message = "Fine-grained power management requires PRIME offload.";
          }
          {
            assertion = cfg.gsp.enable -> (nvidia_x11 ? firmware);
            message = "This NVIDIA driver version does not provide GSP firmware.";
          }
        ];

        # Blacklist conflicting modules
        boot.blacklistedKernelModules = [
          "nouveau"
          "nvidiafb"
        ];

        # Load nvidia-uvm lazily after udev rules are applied
        boot.extraModprobeConfig = ''
          softdep nvidia post: nvidia-uvm
        '';

        # Load nvidia-uvm eagerly for open modules (needed for CUDA)
        boot.kernelModules = [
          "nvidia"
          "nvidia_modeset"
          "nvidia_drm"
        ]
        ++ lib.optionals useOpenModules [ "nvidia_uvm" ];

        # Install the kernel module
        boot.extraModulePackages = if useOpenModules then [ nvidia_x11.open ] else [ nvidia_x11 ];

        # Kernel modesetting for Wayland
        boot.kernelParams =
          lib.optionals cfg.modesetting.enable [ "nvidia-drm.modeset=1" ]
          ++ lib.optionals (cfg.modesetting.enable && lib.versionAtLeast nvidia_x11.version "545") [
            "nvidia-drm.fbdev=1"
          ];

        # udev rules for /dev/nvidia* device creation
        services.udev.extraRules = ''
          KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c 195 255'"
          KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'for i in $$(cat /proc/driver/nvidia/gpus/*/information | grep Minor | cut -d \  -f 4); do mknod -m 666 /dev/nvidia$${i} c 195 $${i}; done'"
          KERNEL=="nvidia_modeset", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-modeset c 195 254'"
          KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 0'"
          KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm-tools c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 1'"
        '';

        # Graphics stack
        hardware.graphics = {
          enable = lib.mkDefault true;
          enable32Bit = lib.mkDefault true;
          extraPackages = [ nvidia_x11.out ];
          extraPackages32 = [ nvidia_x11.lib32 ];
        };

        # GSP firmware
        hardware.firmware = lib.optional cfg.gsp.enable nvidia_x11.firmware;

        # Driver binaries (nvidia-smi, etc.)
        environment.systemPackages = [
          nvidia_x11.bin
        ]
        ++ lib.optional cfg.nvidiaSettings nvidia_x11.settings
        ++ lib.optional cfg.nvidiaPersistenced nvidia_x11.persistenced;
      }

      # Power management suspend/resume services
      (lib.mkIf cfg.powerManagement.enable {
        boot.extraModprobeConfig = ''
          options nvidia NVreg_PreserveVideoMemoryAllocations=1
        '';
      })

      # Fine-grained power management (RTD3) udev rules
      (lib.mkIf cfg.powerManagement.finegrained {
        boot.extraModprobeConfig = ''
          options nvidia NVreg_DynamicPowerManagement=0x02
        '';

        services.udev.extraRules = ''
          # Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
          ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
          ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

          # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
          ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
          ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
        '';
      })

      # PRIME offload convenience script
      (lib.mkIf pCfg.offload.enable {
        environment.systemPackages = [
          (pkgs.writeShellScriptBin "nvidia-offload" ''
            export __NV_PRIME_RENDER_OFFLOAD=1
            export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
            export __GLX_VENDOR_LIBRARY_NAME=nvidia
            export __VK_LAYER_NV_optimus=NVIDIA_only
            exec "$@"
          '')
        ];
      })

      # Reverse sync implies offloading
      (lib.mkIf pCfg.reverseSync.enable {
        hardware.nvidia.prime.offload.enable = lib.mkDefault true;
      })
    ]
  );
}

{
  pkgs,
  # This is meant to be be a list of overlays
  # TODO(corepkgs): make a config.overlays.linux
  kernelPackagesExtensions ? [ ],
  config,
  buildPackages,
  stdenv,
  stdenvNoCC,
  newScope,
  lib,
  fetchurl,
}:

let
  inherit (lib) recurseIntoAttrs dontRecurseIntoAttrs;

  markBroken =
    drv:
    drv.overrideAttrs (
      {
        meta ? { },
        ...
      }:
      {
        meta = meta // {
          broken = true;
        };
      }
    );

  kernelPatches = pkgs.callFromScope ./kernel/patches.nix { };

  # Hardened Linux
  hardenedKernelFor =
    kernel': overrides:
    let
      kernel = kernel'.override overrides;
      version = kernelPatches.hardened.${kernel.meta.branch}.version;
      major = lib.versions.major version;
      sha256 = kernelPatches.hardened.${kernel.meta.branch}.sha256;
      modDirVersion' = builtins.replaceStrings [ kernel.version ] [ version ] kernel.modDirVersion;
    in
    kernel.override {
      structuredExtraConfig = import ./kernel/hardened/config.nix {
        inherit stdenv lib version;
      };
      argsOverride = {
        inherit version;
        pname = "linux-hardened";
        modDirVersion = modDirVersion' + kernelPatches.hardened.${kernel.meta.branch}.extra;
        src = fetchurl {
          url = "mirror://kernel/linux/kernel/v${major}.x/linux-${version}.tar.xz";
          inherit sha256;
        };
        extraMeta = {
          broken = kernel.meta.broken;
        };
      };
      kernelPatches = kernel.kernelPatches ++ [
        kernelPatches.hardened.${kernel.meta.branch}
      ];
      isHardened = true;
    };
in

# TODO (corepkgs): make into spliced scope for cross compilation
lib.makeScope pkgs.newScope (
  linux: with linux; {
    inherit kernelPatches;

    buildLinux = callPackage ./kernel/generic.nix { };

    # Build a mainline kernel from a branch name
    buildMainlineKernel =
      branch:
      callPackage ./kernel/mainline.nix {
        inherit branch;
        kernelPatches = [
          kernelPatches.bridge_stp_helper
          kernelPatches.request_key_helper
        ];
      };

    inherit hardenedKernelFor;

    # Build specialty kernels
    buildRpiKernel =
      rpiVersion:
      callPackage ./kernel/linux-rpi.nix {
        kernelPatches = with kernelPatches; [
          bridge_stp_helper
          request_key_helper
        ];
        inherit rpiVersion;
      };

    buildRtKernel =
      branch:
      callPackage ./kernel/rt/generic.nix {
        inherit branch;
        kernelPatches = [
          kernelPatches.bridge_stp_helper
          kernelPatches.request_key_helper
          kernelPatches.export-rt-sched-migrate
        ];
      };

    zenKernels = callPackage ./kernel/zen-kernels.nix;
    xanmodKernels = callPackage ./kernel/xanmod-kernels.nix;

    buildZenKernel =
      variant:
      zenKernels {
        inherit variant;
        kernelPatches = [
          kernelPatches.bridge_stp_helper
          kernelPatches.request_key_helper
        ];
      };

    buildXanmodKernel =
      variant:
      xanmodKernels {
        inherit variant;
        kernelPatches = [
          kernelPatches.bridge_stp_helper
          kernelPatches.request_key_helper
        ];
      };

    /*
      Linux kernel modules are inherently tied to a specific kernel.  So
      rather than provide specific instances of those packages for a
      specific kernel, we have a function that builds those packages
      for a specific kernel.  This function can then be called for
      whatever kernel you're using.
    */

    packagesFor =
      kernel_:
      (lib.makeExtensible (
        self:
        with self;
        let
          callPackage = newScope self;
        in
        {
          inherit callPackage;
          kernel = kernel_;
          inherit (kernel) stdenv; # in particular, use the same compiler by default

          # to help determine module compatibility
          inherit (kernel)
            isLTS
            isZen
            isHardened
            isLibre
            ;
          inherit (kernel) kernelOlder kernelAtLeast;
          kernelModuleMakeFlags = self.kernel.commonMakeFlags ++ [
            "KBUILD_OUTPUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
          ];
          # Obsolete aliases (these packages do not depend on the kernel).
          inherit (pkgs) oci-seccomp-bpf-hook; # added 2022-11
          inherit (pkgs) dpdk; # added 2024-03

          acer-wmi-battery = callPackage ./pkgs/acer-wmi-battery { };

          acpi_call = callPackage ./pkgs/acpi-call { };

          ajantv2 = callPackage ./pkgs/ajantv2 { };

          akvcam = callPackage ./pkgs/akvcam { };

          amdgpu-i2c = callPackage ./pkgs/amdgpu-i2c { };

          amneziawg = callPackage ./pkgs/amneziawg { };

          apfs = callPackage ./pkgs/apfs { };

          ax99100 = callPackage ./pkgs/ax99100 { };

          batman_adv = callPackage ./pkgs/batman-adv { };

          bbswitch = callPackage ./pkgs/bbswitch { };

          # NOTE: The bcachefs module is called this way to facilitate
          # easy overriding, as it is expected many users will want to
          # pull from the upstream git repo, which may include
          # unreleased changes to the module build process.
          bcachefs = callPackage pkgs.bcachefs-tools.kernelModule { };

          ch9344 = callPackage ./pkgs/ch9344 { };

          chipsec = callPackage ./pkgs/chipsec {
            inherit kernel;
            withDriver = true;
          };

          cryptodev = callPackage ./pkgs/cryptodev { };

          cpupower = callPackage ./pkgs/cpupower { };

          ddcci-driver = callPackage ./pkgs/ddcci { };

          dddvb = callPackage ./pkgs/dddvb { };

          decklink = callPackage ./pkgs/decklink { };

          digimend = callPackage ./pkgs/digimend { };

          dpdk-kmods = callPackage ./pkgs/dpdk-kmods { };

          # ecapture removed: references non-existent nixpkgs path

          evdi = callPackage ./pkgs/evdi { };

          fanout = callPackage ./pkgs/fanout { };

          framework-laptop-kmod = callPackage ./pkgs/framework-laptop-kmod { };

          fwts-efi-runtime = callPackage ./pkgs/fwts/module.nix { };

          gasket = callPackage ./pkgs/gasket { };

          gcadapter-oc-kmod = callPackage ./pkgs/gcadapter-oc-kmod { };

          hyperv-daemons = callPackage ./pkgs/hyperv-daemons { };

          e1000e = if lib.versionOlder kernel.version "4.10" then callPackage ./pkgs/e1000e { } else null;

          iio-utils =
            if lib.versionAtLeast kernel.version "4.1" then callPackage ./pkgs/iio-utils { } else null;

          intel-speed-select =
            if lib.versionAtLeast kernel.version "5.3" then callPackage ./pkgs/intel-speed-select { } else null;

          ipu6-drivers = callPackage ./pkgs/ipu6-drivers { };

          ivsc-driver = callPackage ./pkgs/ivsc-driver { };

          ixgbevf = callPackage ./pkgs/ixgbevf { };

          it87 = callPackage ./pkgs/it87 { };

          asus-ec-sensors = callPackage ./pkgs/asus-ec-sensors { };

          ena = callPackage ./pkgs/ena { };

          lenovo-legion-module = callPackage ./pkgs/lenovo-legion { };

          # linux-gpib removed: references non-existent nixpkgs path

          liquidtux = callPackage ./pkgs/liquidtux { };

          lkrg = callPackage ./pkgs/lkrg { };

          v4l2loopback = callPackage ./pkgs/v4l2loopback { };

          lttng-modules = callPackage ./pkgs/lttng-modules { };

          mstflint_access = callPackage ./pkgs/mstflint_access { };

          broadcom_sta = callPackage ./pkgs/broadcom-sta { };

          tbs = callPackage ./pkgs/tbs { };

          mbp2018-bridge-drv = callPackage ./pkgs/mbp-modules/mbp2018-bridge-drv { };

          nct6687d = callPackage ./pkgs/nct6687d { };

          new-lg4ff = callPackage ./pkgs/new-lg4ff { };

          zenergy = callPackage ./pkgs/zenergy { };

          nvidiabl = callPackage ./pkgs/nvidiabl { };

          nvidiaPackages = dontRecurseIntoAttrs (lib.makeExtensible (_: callPackage ./pkgs/nvidia-x11 { }));

          nvidia_x11 = nvidiaPackages.stable;
          nvidia_x11_beta = nvidiaPackages.beta;
          nvidia_x11_latest = nvidiaPackages.latest;
          nvidia_x11_legacy340 = nvidiaPackages.legacy_340;
          nvidia_x11_legacy390 = nvidiaPackages.legacy_390;
          nvidia_x11_legacy470 = nvidiaPackages.legacy_470;
          nvidia_x11_legacy535 = nvidiaPackages.legacy_535;
          nvidia_x11_production = nvidiaPackages.production;
          nvidia_x11_vulkan_beta = nvidiaPackages.vulkan_beta;
          nvidia_dc = nvidiaPackages.dc;
          nvidia_dc_535 = nvidiaPackages.dc_535;
          nvidia_dc_565 = nvidiaPackages.dc_565;

          # this is not a replacement for nvidia_x11*
          # only the opensource kernel driver exposed for hydra to build
          nvidia_x11_beta_open = nvidiaPackages.beta.open;
          nvidia_x11_latest_open = nvidiaPackages.latest.open;
          nvidia_x11_production_open = nvidiaPackages.production.open;
          nvidia_x11_stable_open = nvidiaPackages.stable.open;
          nvidia_x11_vulkan_beta_open = nvidiaPackages.vulkan_beta.open;

          nxp-pn5xx = callPackage ./pkgs/nxp-pn5xx { };

          # openrazer removed: references non-existent path ../pkgs/development/python-modules/openrazer/common.nix

          ply = callPackage ./pkgs/ply { };

          r8125 = callPackage ./pkgs/r8125 { };

          r8168 = callPackage ./pkgs/r8168 { };

          rtl8188eus-aircrack = callPackage ./pkgs/rtl8188eus-aircrack { };

          rtl8192eu = callPackage ./pkgs/rtl8192eu { };

          rtl8189es = callPackage ./pkgs/rtl8189es { };

          rtl8189fs = callPackage ./pkgs/rtl8189fs { };

          rtl8723ds = callPackage ./pkgs/rtl8723ds { };

          rtl8812au = callPackage ./pkgs/rtl8812au { };

          rtl8814au = callPackage ./pkgs/rtl8814au { };

          rtl8852au = callPackage ./pkgs/rtl8852au { };

          rtl8852bu = callPackage ./pkgs/rtl8852bu { };

          rtl88xxau-aircrack = callPackage ./pkgs/rtl88xxau-aircrack { };

          rtl8821au = callPackage ./pkgs/rtl8821au { };

          rtl8821ce = callPackage ./pkgs/rtl8821ce { };

          rtl88x2bu = callPackage ./pkgs/rtl88x2bu { };

          rtl8821cu = callPackage ./pkgs/rtl8821cu { };

          rtw88 = callPackage ./pkgs/rtw88 { };

          rtw89 = if lib.versionOlder kernel.version "5.16" then callPackage ./pkgs/rtw89 { } else null;

          # openafs_1_8 and openafs removed: references non-existent nixpkgs path

          opensnitch-ebpf =
            if lib.versionAtLeast kernel.version "5.10" then callPackage ./pkgs/opensnitch-ebpf { } else null;

          facetimehd = callPackage ./pkgs/facetimehd { };

          rust-out-of-tree-module =
            if lib.versionAtLeast kernel.version "6.7" then
              callPackage ./pkgs/rust-out-of-tree-module { }
            else
              null;

          tuxedo-drivers =
            if lib.versionAtLeast kernel.version "4.14" then callPackage ./pkgs/tuxedo-drivers { } else null;

          jool = callPackage ./pkgs/jool { };

          kvmfr = callPackage ./pkgs/kvmfr { };

          mba6x_bl = callPackage ./pkgs/mba6x_bl { };

          mdio-netlink = callPackage ./pkgs/mdio-netlink { };

          mwprocapture = callPackage ./pkgs/mwprocapture { };

          mxu11x0 = callPackage ./pkgs/mxu11x0 { };

          morse-driver = callPackage ./pkgs/morse-driver { };

          # compiles but has to be integrated into the kernel somehow
          # Let's have it uncommented and finish it..
          ndiswrapper = callPackage ./pkgs/ndiswrapper { };

          netatop = callPackage ./pkgs/netatop { };

          isgx = callPackage ./pkgs/isgx { };

          # rr-zen_workaround removed: references non-existent nixpkgs path

          sheep-net = callPackage ./pkgs/sheep-net { };

          shufflecake = callPackage ./pkgs/shufflecake { };

          sysdig = callPackage ./pkgs/sysdig { };

          # systemtap removed: references non-existent nixpkgs path

          system76 = callPackage ./pkgs/system76 { };

          system76-acpi = callPackage ./pkgs/system76-acpi { };

          system76-io = callPackage ./pkgs/system76-io { };

          tmon = callPackage ./pkgs/tmon { };

          tp_smapi = callPackage ./pkgs/tp_smapi { };

          tt-kmd = callPackage ./pkgs/tt-kmd { };

          turbostat = callPackage ./pkgs/turbostat { };

          corefreq = callPackage ./pkgs/corefreq { };

          trelay = callPackage ./pkgs/trelay { };

          universal-pidff = callPackage ./pkgs/universal-pidff { };

          usbip = callPackage ./pkgs/usbip { };

          v86d = callPackage ./pkgs/v86d { };

          veikk-linux-driver = callPackage ./pkgs/veikk-linux-driver { };
          vendor-reset = callPackage ./pkgs/vendor-reset { };

          # vhba removed: references non-existent nixpkgs path

          virtio_vmmci = callPackage ./pkgs/virtio_vmmci { };

          virtualbox = throw "linuxPackages.virtualbox requires virtualboxHardened which is not available";

          # virtualboxGuestAdditions removed: references non-existent nixpkgs path

          mm-tools = callPackage ./pkgs/mm-tools { };

          vmm_clock = callPackage ./pkgs/vmm_clock { };

          vmware = callPackage ./pkgs/vmware { };

          wireguard =
            if lib.versionOlder kernel.version "5.6" then callPackage ./pkgs/wireguard { } else null;

          x86_energy_perf_policy = callPackage ./pkgs/x86_energy_perf_policy { };

          xone = if lib.versionAtLeast kernel.version "5.4" then callPackage ./pkgs/xone { } else null;

          xpadneo = callPackage ./pkgs/xpadneo { };

          yt6801 = callPackage ./pkgs/yt6801 { };

          ithc = callPackage ./pkgs/ithc { };

          ryzen-smu = callPackage ./pkgs/ryzen-smu { };

          zenpower = callPackage ./pkgs/zenpower { };

          zfs_2_3 = callPackage ./pkgs/zfs/2_3.nix {
            configFile = "kernel";
            inherit pkgs kernel;
          };
          zfs_2_4 = callPackage ./pkgs/zfs/2_4.nix {
            configFile = "kernel";
            inherit pkgs kernel;
          };
          zfs_unstable = callPackage ./pkgs/zfs/unstable.nix {
            configFile = "kernel";
            inherit pkgs kernel;
          };

          can-isotp = callPackage ./pkgs/can-isotp { };

          qc71_laptop = callPackage ./pkgs/qc71_laptop { };

          hid-ite8291r3 = callPackage ./pkgs/hid-ite8291r3 { };

          hid-t150 = callPackage ./pkgs/hid-t150 { };

          hid-tmff2 = callPackage ./pkgs/hid-tmff2 { };

          hpuefi-mod = callPackage ./pkgs/hpuefi-mod { };

          drbd = callPackage ./pkgs/drbd/driver.nix { };

          nullfs = callPackage ./pkgs/nullfs { };

          msi-ec = callPackage ./pkgs/msi-ec { };

          tsme-test = callPackage ./pkgs/tsme-test { };

          xpad-noone = callPackage ./pkgs/xpad-noone { };

        }
        // lib.optionalAttrs config.allowAliases {
          zfs = throw "linuxPackages.zfs has been removed, use zfs_* instead, or linuxPackages.\${pkgs.zfs.kernelModuleAttribute}"; # added 2025-01-23
          zfs_2_1 = throw "zfs_2_1 has been removed"; # added 2024-12-25;
          ati_drivers_x11 = throw "ati drivers are no longer supported by any kernel >=4.1"; # added 2021-05-18;
          deepin-anything-module = throw "the Deepin desktop environment and associated tools have been removed from nixpkgs due to lack of maintenance";
          exfat-nofuse = throw "exfat-nofuse has been removed, all kernels > 5.8 come with built-in exfat support"; # added 2025-10-07
          hid-nintendo = throw "hid-nintendo was added in mainline kernel version 5.16"; # Added 2023-07-30
          sch_cake = throw "sch_cake was added in mainline kernel version 4.19"; # Added 2023-06-14
          rtl8723bs = throw "rtl8723bs was added in mainline kernel version 4.12"; # Added 2023-06-14
          vm-tools = self.mm-tools;
          xmm7360-pci = throw "Support for the XMM7360 WWAN card was added to the iosm kmod in mainline kernel version 5.18";
          amdgpu-pro = throw "amdgpu-pro was removed due to lack of maintenance"; # Added 2024-06-16
          kvdo = throw "kvdo was removed, because it was added to mainline in kernel version 6.9"; # Added 2024-07-08
          system76-power = throw "linuxPackages.system76-power has been removed"; # Added 2024-10-16
          system76-scheduler = throw "linuxPackages.system76-scheduler has been removed"; # Added 2024-10-16
          tuxedo-keyboard = self.tuxedo-drivers; # Added 2024-09-28
          phc-intel = throw "phc-intel drivers are no longer supported by any kernel >=4.17"; # added 2025-07-18
          prl-tools = throw "Parallel Tools no longer provide any kernel module, please use pkgs.prl-tools instead."; # added 2025-10-04
        }
      )).extend
        (lib.fixedPoints.composeManyExtensions kernelPackagesExtensions);

    hardenedPackagesFor = kernel: overrides: packagesFor (hardenedKernelFor kernel overrides);

    manualConfig = callPackage ./kernel/build.nix { };

    customPackage =
      {
        version,
        src,
        modDirVersion ? lib.versions.pad 3 version,
        configfile,
        allowImportFromDerivation ? false,
      }:
      recurseIntoAttrs (
        packagesFor (manualConfig {
          inherit
            version
            src
            modDirVersion
            configfile
            allowImportFromDerivation
            ;
        })
      );

    # Derive one of the default .config files
    linuxConfig =
      {
        src,
        kernelPatches ? [ ],
        version ? (builtins.parseDrvName src.name).version,
        makeTarget ? "defconfig",
        name ? "kernel.config",
      }:
      stdenvNoCC.mkDerivation {
        inherit name src;
        depsBuildBuild = [
          buildPackages.stdenv.cc
        ]
        ++ lib.optionals (lib.versionAtLeast version "4.16") [
          buildPackages.bison
          buildPackages.flex
        ];
        patches = map (p: p.patch) kernelPatches; # Patches may include new configs.
        postPatch = ''
          patchShebangs scripts/
        '';
        buildPhase = ''
          set -x
          make \
            ARCH=${stdenv.hostPlatform.linuxArch} \
            HOSTCC=${buildPackages.stdenv.cc.targetPrefix}gcc \
            ${makeTarget}
        '';
        installPhase = ''
          cp .config $out
        '';
      };

  }
)

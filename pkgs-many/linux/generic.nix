{
  branch,
  isLTS,
  mkVariantPassthru,
  ...
}@variantArgs:

{
  lib,
  callPackage,
  linux-support,
  # Accept kernel-level overrides that may be passed via .override
  preferBuiltin ? false,
}:

let
  # Build the mainline kernel for this variant's branch
  baseKernel = linux-support.buildMainlineKernel branch;
  kernel = if preferBuiltin then baseKernel.override { inherit preferBuiltin; } else baseKernel;

  # Build the kernel module scope (linuxPackages) for this kernel
  kernelPackages = linux-support.packagesFor kernel;

  # Specialty kernels — built lazily, only evaluated when accessed
  specialtyKernels = {
    # Real-time kernels
    rt_5_10 = wrapKernel (linux-support.buildRtKernel "5.10");
    rt_5_15 = wrapKernel (linux-support.buildRtKernel "5.15");
    rt_6_1 = wrapKernel (linux-support.buildRtKernel "6.1");
    rt_6_6 = wrapKernel (linux-support.buildRtKernel "6.6");
    rt_6_12 = wrapKernel (linux-support.buildRtKernel "6.12");

    # Raspberry Pi kernels
    rpi1 = wrapKernel (linux-support.buildRpiKernel 1);
    rpi2 = wrapKernel (linux-support.buildRpiKernel 2);
    rpi3 = wrapKernel (linux-support.buildRpiKernel 3);
    rpi4 = wrapKernel (linux-support.buildRpiKernel 4);

    # Zen/LQX kernels
    zen = wrapKernel (linux-support.buildZenKernel "zen");
    lqx = wrapKernel (linux-support.buildZenKernel "lqx");

    # XanMod kernels
    xanmod = wrapKernel (linux-support.buildXanmodKernel "lts");
    xanmod_stable = wrapKernel (linux-support.buildXanmodKernel "main");
    xanmod_latest = wrapKernel (linux-support.buildXanmodKernel "main");

    # Hardened kernel (based on the default/6.12 kernel)
    hardened = wrapKernel (
      linux-support.hardenedKernelFor (linux-support.buildMainlineKernel "6.12") { }
    );
    hardened_6_12 = wrapKernel (
      linux-support.hardenedKernelFor (linux-support.buildMainlineKernel "6.12") { }
    );

    # Testing kernel
    testing =
      let
        testingKernel = linux-support.buildMainlineKernel "testing";
        latestKernel = linux-support.buildMainlineKernel "7.2";
      in
      wrapKernel (
        if latestKernel.kernelAtLeast testingKernel.baseVersion then latestKernel else testingKernel
      );
  };

  # Wrap a specialty kernel to add .pkgs passthru
  wrapKernel =
    k:
    k.overrideAttrs (oldAttrs: {
      passthru = (oldAttrs.passthru or { }) // {
        pkgs = linux-support.packagesFor k;
      };
    });

in
# Return the mainline kernel with variant passthru + .pkgs + specialty kernels
kernel.overrideAttrs (oldAttrs: {
  passthru =
    (oldAttrs.passthru or { })
    // mkVariantPassthru variantArgs
    // specialtyKernels
    // {
      pkgs = kernelPackages;
      inherit variantArgs;
      makeInitrd = callPackage ./makeInitrd;
      makeModulesClosure = callPackage ./makeModulesClosure;
      ekapkgs-update.semver-strategy = "patch";
    };
})

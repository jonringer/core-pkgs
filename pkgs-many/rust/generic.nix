# New rust versions should first go to staging.
# Things to check after updating:
# 1. Rustc should produce rust binaries on x86_64-linux and aarch64-linux:
#    i.e. nix-shell -p fd or @GrahamcOfBorg build fd on github
#    This testing can be also done by other volunteers as part of the pull
#    request review, in case platforms cannot be covered.
# 2. The LLVM version used for building should match with rust upstream.
#    Check the version number in the src/llvm-project git submodule in:
#    https://github.com/rust-lang/rust/blob/<version-tag>/.gitmodules

# First parameter set: variant args from variants.nix (injected by mkManyVariants)
{
  rustcVersion,
  rustcSha256,
  bootstrapVersion,
  bootstrapHashes,
  selectRustPackage,
  rustcPatches ? [ ],
  enableRustcDev ? true,
  mkVariantPassthru,
  packageAtLeast,
  packageOlder,
  packageBetween,
  ...
}@variantArgs:

# Second parameter set: package dependencies (resolved by callPackage)
{
  stdenv,
  lib,
  newScope,
  callPackage,
  pkgsBuildBuild,
  pkgsBuildHost,
  pkgsBuildTarget,
  pkgsHostTarget,
  pkgsTargetTarget,
  makeRustPlatform,
  llvmPackages,
  llvm,
  wrapCCWith,
  overrideCC,
}@args:

let
  llvmSharedFor =
    pkgSet:
    pkgSet.llvmPackages.libllvm.override (
      {
        enableSharedLibraries = true;
      }
      // lib.optionalAttrs (stdenv.targetPlatform.useLLVM or false) {
        # Force LLVM to compile using clang + LLVM libs when targeting pkgsLLVM
        stdenv = pkgSet.stdenv.override {
          allowedRequisites = null;
          cc = pkgSet.pkgsBuildHost.llvmPackages.clangUseLLVM;
        };
      }
    );

  llvmShared = llvmSharedFor pkgsHostTarget;
  llvmSharedForBuild = llvmSharedFor pkgsBuildBuild;
  llvmSharedForHost = llvmSharedFor pkgsBuildHost;
  llvmSharedForTarget = llvmSharedFor pkgsBuildTarget;

  # Use `import` to make sure no packages sneak in here.
  lib' = import ../../pkgs/rust/lib {
    inherit
      lib
      stdenv
      pkgsBuildHost
      pkgsBuildTarget
      pkgsTargetTarget
      ;
  };

  # Allow faster cross compiler generation by reusing Build artifacts
  fastCross =
    (stdenv.buildPlatform == stdenv.hostPlatform) && (stdenv.hostPlatform != stdenv.targetPlatform);

  packages = {
    prebuilt = callPackage ./bootstrap.nix {
      version = bootstrapVersion;
      hashes = bootstrapHashes;
    };
    stable = lib.makeScope newScope (
      self:
      let
        # Like `buildRustPackages`, but may also contain prebuilt binaries to
        # break cycle. Just like `bootstrapTools` for nixpkgs as a whole,
        # nothing in the final package set should refer to this.
        bootstrapRustPackages =
          if fastCross then
            pkgsBuildBuild.rustPackages
          else
            self.buildRustPackages.overrideScope (
              _: _:
              lib.optionalAttrs (stdenv.buildPlatform == stdenv.hostPlatform)
                (selectRustPackage pkgsBuildHost).packages.prebuilt
            );
        bootRustPlatform = makeRustPlatform bootstrapRustPackages;
      in
      {
        # Packages suitable for build-time, e.g. `build.rs`-type stuff.
        buildRustPackages = (selectRustPackage pkgsBuildHost).packages.stable;
        # Analogous to stdenv
        rustPlatform = makeRustPlatform self.buildRustPackages;
        rustc-unwrapped = self.callPackage ./rustc.nix {
          version = rustcVersion;
          sha256 = rustcSha256;
          inherit enableRustcDev;
          inherit
            llvmShared
            llvmSharedForBuild
            llvmSharedForHost
            llvmSharedForTarget
            llvmPackages
            fastCross
            ;

          patches = rustcPatches;

          # Use boot package set to break cycle
          inherit (bootstrapRustPackages) cargo rustc rustfmt;
        };
        wrapRustcWith = args: self.callPackage ./rustc-wrapper args;
        wrapRustc = rustc-unwrapped: self.wrapRustcWith { inherit rustc-unwrapped; };
        rustc = self.wrapRustcWith {
          inherit (self) rustc-unwrapped;
          sysroot = if fastCross then self.rustc-unwrapped else null;
        };
        rustfmt = self.callPackage ./rustfmt.nix {
          inherit (self.buildRustPackages) rustc;
        };
        cargo =
          if (!fastCross) then
            self.callPackage ./cargo.nix {
              # Use boot package set to break cycle
              rustPlatform = bootRustPlatform;
            }
          else
            self.callPackage ./cargo_cross.nix { };
        cargo-auditable = self.callPackage ./cargo-auditable.nix { };
        cargo-auditable-cargo-wrapper = self.callPackage ./cargo-auditable-cargo-wrapper.nix { };
        clippy-unwrapped = self.callPackage ./clippy.nix { };
        clippy = if !fastCross then self.clippy-unwrapped else self.callPackage ./clippy-wrapper.nix { };
      }
    );
  };

  mainRustc = packages.stable.rustc;
in
mainRustc.overrideAttrs (oldAttrs: {
  passthru = (oldAttrs.passthru or { }) // {
    inherit packages;
    pkgs = packages.stable;

    lib = lib';

    # Backwards compat before `lib` was factored out.
    inherit (lib')
      toTargetArch
      toTargetOs
      toRustTarget
      toRustTargetSpec
      IsNoStdTarget
      toRustTargetForUseInEnvVars
      envVars
      ;

    ekapkgs-update.semver-strategy = "patch";
  };
})

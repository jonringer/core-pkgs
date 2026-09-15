{
  localSystem,
  config,
  lib,
  bootstrapFiles,
}:
let
  minbootSupportedSystems = [
    "i686-linux"
    "x86_64-linux"
  ];
  minbootSupported = builtins.elem localSystem.system minbootSupportedSystems;

  callPackage = lib.callPackageWith { inherit lib config; };

  # Built here rather than in `top-level.nix` so that there is a single scope:
  # what `pkgs.minimal-bootstrap` exposes is exactly what the stdenv on this
  # system was grown from, and the two cannot drift apart.
  minimal-bootstrap = lib.recurseIntoAttrs (
    import ../minimal-bootstrap {
      buildPlatform = localSystem;
      hostPlatform = localSystem;
      inherit lib config;
      # corepkgs' bootstrap fetcher takes only `system`; the builtin fetcher
      # ignores it either way, since it builds with `system = "builtin"`.
      fetchurl = import ../../pkgs/fetchurl/bootstrap.nix {
        inherit (localSystem) system;
      };
      checkMeta = callPackage ../generic/check-meta.nix { };
    }
  );
in
if minbootSupported then
  let
    compilerPackage =
      if localSystem.libc == "glibc" then
        minimal-bootstrap.gcc-glibc
      else if localSystem.libc == "musl" then
        minimal-bootstrap.gcc-latest
      else
        throw "Can't bootstrap on ${localSystem.config}";
    libcPackage =
      if localSystem.libc == "glibc" then
        minimal-bootstrap.glibc
      else if localSystem.libc == "musl" then
        minimal-bootstrap.musl-static
      else
        throw "Can't bootstrap on ${localSystem.config}";
  in
  assert minimal-bootstrap.bash-static.passthru.isFromMinBootstrap or false; # sanity check
  {
    inherit minimal-bootstrap;
    isMinimalBootstrap = true;

    dummyStdenv = {
      name = "bootstrap-stage0";

      overrides = self: super: {
        # We thread stage0's stdenv through under this name so downstream stages
        # can use it for wrapping gcc too. This way, downstream stages don't need
        # to refer to this stage directly, which violates the principle that each
        # stage should only access the stage that came before it.
        ccWrapperStdenv = self.stdenv;
        # The Glibc include directory cannot have the same prefix as the
        # GCC include directory, since GCC gets confused otherwise (it
        # will search the Glibc headers before the GCC headers).  So
        # create a dummy Glibc here, which will be used in the stdenv of
        # stage1.
        ${localSystem.libc} = self.stdenv.mkDerivation {
          pname = "bootstrap-stage0-${localSystem.libc}";
          version = "minimal-bootstrap";
          buildCommand = ''
            mkdir -p $out
            ln -s ${libcPackage}/lib $out/lib
            ln -s ${libcPackage}/include $out/include
          '';
          passthru.isFromBootstrapFiles = true;
        };
        gcc-unwrapped = compilerPackage;
        binutils = import ../bintools-wrapper {
          name = "bootstrap-stage0-binutils-wrapper";
          nativeTools = false;
          nativeLibc = false;
          expand-response-params = "";
          inherit lib;
          inherit (self)
            stdenvNoCC
            coreutils
            grep
            libc
            ;
          bintools = minimal-bootstrap.binutils-static;
          runtimeShell = "${minimal-bootstrap.bash}/bin/bash";
        };
        coreutils = minimal-bootstrap.coreutils-static;
        grep = minimal-bootstrap.grep-static;
      };
    };
    bash = minimal-bootstrap.bash-static;
    initialPath = with minimal-bootstrap; [
      bash-static
      binutils-static
      bzip2-static
      compilerPackage
      coreutils-static
      diffutils-static
      findutils-static
      gawk-static
      grep-static
      gzip-static
      make-static
      patch-static
      patchelf-static
      sed-static
      tar-static
      xz-static
    ];
    disallowedInFinalStdenv = lib.attrsets.catAttrs "out" (
      builtins.filter (drv: lib.attrsets.isDerivation drv) (builtins.attrValues minimal-bootstrap)
    );
  }
else
  let
    # Download and unpack the bootstrap tools (coreutils, GCC, Glibc, ...).
    bootstrapTools = import ./bootstrap-tools {
      inherit (localSystem) libc system;
      inherit lib bootstrapFiles config;
      isFromBootstrapFiles = true;
    };
  in
  assert bootstrapTools.passthru.isFromBootstrapFiles or false; # sanity check
  {
    inherit bootstrapTools minimal-bootstrap;
    isMinimalBootstrap = false;

    dummyStdenv = {
      name = "bootstrap-stage0";

      overrides = self: super: {
        # We thread stage0's stdenv through under this name so downstream stages
        # can use it for wrapping gcc too. This way, downstream stages don't need
        # to refer to this stage directly, which violates the principle that each
        # stage should only access the stage that came before it.
        ccWrapperStdenv = self.stdenv;
        # The Glibc include directory cannot have the same prefix as the
        # GCC include directory, since GCC gets confused otherwise (it
        # will search the Glibc headers before the GCC headers).  So
        # create a dummy Glibc here, which will be used in the stdenv of
        # stage1.
        ${localSystem.libc} = self.stdenv.mkDerivation {
          pname = "bootstrap-stage0-${localSystem.libc}";
          version = "bootstrapFiles";
          buildCommand = ''
            mkdir -p $out
            ln -s ${bootstrapTools}/lib $out/lib
          ''
          + lib.optionalString (localSystem.libc == "glibc") ''
            ln -s ${bootstrapTools}/include-glibc $out/include
          ''
          + lib.optionalString (localSystem.libc == "musl") ''
            ln -s ${bootstrapTools}/include-libc $out/include
          '';
          passthru.isFromBootstrapFiles = true;
        };
        gcc-unwrapped = bootstrapTools;
        binutils = import ../bintools-wrapper {
          name = "bootstrap-stage0-binutils-wrapper";
          nativeTools = false;
          nativeLibc = false;
          expand-response-params = "";
          inherit lib;
          inherit (self)
            stdenvNoCC
            coreutils
            grep
            libc
            ;
          bintools = bootstrapTools;
          runtimeShell = "${bootstrapTools}/bin/bash";
        };
        coreutils = bootstrapTools;
        grep = bootstrapTools;
      };
    };
    bash = bootstrapTools;
    initialPath = [ bootstrapTools ];
    disallowedInFinalStdenv = [ bootstrapTools ];
  }

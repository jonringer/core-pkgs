{
  lib,
  stdenv,
  makeSetupHook,
  runCommand,
  glibc,
  gcc,
  targetPackages,
}:

let
  libs = import ./libraries.nix { inherit lib; };

  # Escape a string for a C string literal (between double quotes).
  cEscape =
    s:
    let
      sub =
        s: from: to:
        builtins.replaceStrings [ from ] [ to ] s;
      step1 = sub s "\\" "\\\\";
      step2 = sub step1 "\"" "\\\"";
      step3 = sub step2 "\n" "\\n";
      step4 = sub step3 "\r" "\\r";
      step5 = sub step4 "\t" "\\t";
    in
    step5;

  cStr = s: "\"${cEscape s}\"";

  # Build the WDP_LIBRARIES initializer.
  libsInit = lib.concatStringsSep ",\n    " (
    map (l: "{ ${cStr l.name}, ${if l.glob then "1" else "0"} }") libs.libraries
  );

  # Build a static `const char *const NAME[]` array initializer from a list
  # of strings.
  staticStrArray = name: items: ''
    static const char *const ${name}[] = {
        ${lib.concatStringsSep ",\n        " (map cStr items)}
    };
    static const size_t ${name}_N = ${toString (lib.length items)};
  '';

  # Build the WDP_CONFIGS table. We need to emit named arrays for each
  # entry's source_dirs and env_vars, then aggregate them.
  configsArrays = lib.imap0 (i: c: ''
    static const char *const wdp_cfg_${toString i}_dirs[] = {
        ${lib.concatStringsSep ",\n        " (map cStr c.sourceDirs)}
    };
    static const char *const wdp_cfg_${toString i}_envs[] = {
        ${lib.concatStringsSep ",\n        " (map cStr c.envVars)}
    };
  '') libs.configs;

  configsInit = lib.concatStringsSep ",\n    " (
    lib.imap0 (i: c: ''
      {
          .source_dirs = wdp_cfg_${toString i}_dirs,
          .source_dirs_n = ${toString (lib.length c.sourceDirs)},
          .pattern = ${cStr c.pattern},
          .cache_subdir = ${cStr c.cacheSubdir},
          .env_vars = wdp_cfg_${toString i}_envs,
          .env_vars_n = ${toString (lib.length c.envVars)},
          .mode_dir = ${if c.mode == "dir" then "1" else "0"}
      }'') libs.configs
  );

  driverPathsArrays = lib.imap0 (i: d: ''
    static const char *const wdp_drv_${toString i}_cands[] = {
        ${lib.concatStringsSep ",\n        " (map cStr d.candidates)}
    };
  '') libs.driverPaths;

  driverPathsInit = lib.concatStringsSep ",\n    " (
    lib.imap0 (i: d: ''
      {
          .candidates = wdp_drv_${toString i}_cands,
          .candidates_n = ${toString (lib.length d.candidates)},
          .env_var = ${cStr d.envVar}
      }'') libs.driverPaths
  );

  # Hash bound to the configuration; binaries that share the same config will
  # share the cache directory.
  configHash = builtins.substring 0 16 (
    builtins.hashString "sha256" (
      builtins.toJSON {
        inherit (libs) libraries configs driverPaths;
      }
    )
  );

  # Generate the wdp-config.h.in template (shipped to the consumer derivation;
  # the setup hook substitutes the @TOKEN@ placeholders for each binary).
  wdpConfigHeader = runCommand "wdp-config.h.in" { } ''
    cat > $out <<'__WDP_HDR__'
    #ifndef WDP_CONFIG_H_INCLUDED
    #define WDP_CONFIG_H_INCLUDED
    #include <stddef.h>

    static const char *const WDP_REAL_PROGRAM = "@WDP_REAL_PROGRAM@";
    static const char *const WDP_NIX_LIBC      = "@WDP_NIX_LIBC@";
    static const char *const WDP_NIX_LIBSTDCXX = "@WDP_NIX_LIBSTDCXX@";
    static const char *const WDP_NIX_LD_LINUX  = "@WDP_NIX_LD_LINUX@";
    static const char *const WDP_CONFIG_HASH   = "@WDP_CONFIG_HASH@";

    struct wdp_lib { const char *name; int is_glob; };
    static const struct wdp_lib WDP_LIBRARIES[] = {
        ${libsInit}
    };
    static const size_t WDP_LIBRARIES_N =
        sizeof(WDP_LIBRARIES) / sizeof(WDP_LIBRARIES[0]);

    ${lib.concatStrings configsArrays}
    struct wdp_cfg {
        const char *const *source_dirs; size_t source_dirs_n;
        const char *pattern;
        const char *cache_subdir;
        const char *const *env_vars; size_t env_vars_n;
        int mode_dir;
    };
    static const struct wdp_cfg WDP_CONFIGS[] = {
        ${configsInit}
    };
    static const size_t WDP_CONFIGS_N =
        sizeof(WDP_CONFIGS) / sizeof(WDP_CONFIGS[0]);

    ${lib.concatStrings driverPathsArrays}
    struct wdp_drvpath {
        const char *const *candidates; size_t candidates_n;
        const char *env_var;
    };
    static const struct wdp_drvpath WDP_DRIVER_PATHS[] = {
        ${driverPathsInit}
    };
    static const size_t WDP_DRIVER_PATHS_N =
        sizeof(WDP_DRIVER_PATHS) / sizeof(WDP_DRIVER_PATHS[0]);

    #endif /* WDP_CONFIG_H_INCLUDED */
    __WDP_HDR__
  '';

  cc = stdenv.cc;
  ccBin = "${cc}/bin/${cc.targetPrefix or ""}cc";
in
makeSetupHook {
  name = "wrap-driver-program-hook";
  propagatedBuildInputs = [ ];
  substitutions = {
    cc = ccBin;
    wrapperSource = ./wrapper.c;
    wdpConfigHeader = wdpConfigHeader;
    nixGlibc = glibc;
    # libstdc++ lives in gcc's lib output; some toolchains differ.
    nixLibStdCxx = if gcc ? cc then gcc.cc else gcc;
    inherit configHash;
  };
  passthru = {
    inherit configHash;
    inherit (libs) libraries configs driverPaths;
    # Expose a top-level wrapper helper for use outside mkDerivation:
    #   wrapDriverProgram { drv = somepkg; programs = [ "foo" ]; }
    # returns a new derivation that copies somepkg into $out and wraps the
    # listed programs.
    wrapDriverProgram =
      {
        drv,
        programs ? null,
        autoWrap ? programs == null,
      }:
      let
        progArgs =
          if programs == null then "" else lib.concatMapStringsSep " " (p: lib.escapeShellArg p) programs;
        # Detect which output of drv contains binaries
        srcOut = if drv ? bin then "bin" else "out";
      in
      runCommand "${drv.pname or "wrapped"}-driver-wrapped"
        {
          nativeBuildInputs = [
            (import ./. {
              inherit
                lib
                stdenv
                makeSetupHook
                runCommand
                glibc
                gcc
                targetPackages
                ;
            })
          ];
          inherit drv;
          wdpAutoWrap = if autoWrap then "1" else "0";
        }
        ''
          mkdir -p $out
          # Copy the output that contains binaries
          cp -a --reflink=auto "$drv${if srcOut == "bin" then ".bin" else ""}"/* $out/
          chmod -R u+w $out
          if [ "$wdpAutoWrap" = "1" ]; then
            # autoWrapDriverPrograms now correctly uses ''${!outputBin}
            autoWrapDriverPrograms
          else
            for p in ${progArgs}; do
              wrapDriverProgram "$out/bin/$p"
            done
          fi
        '';
  };
} ./wrap-driver-program.sh

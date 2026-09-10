{
  lib,
  pkgs,
  stdenv,
}:

let
  # Import the process-compose translation layer
  pcTranslate = import ../services/lib/process-compose-translate.nix { inherit lib pkgs; };

  # Import service module infrastructure
  serviceLib = import ../services/lib/service-module.nix { inherit lib pkgs; };

  # Language modules for devshell integration
  languageModuleFiles = [
    ../ekaos/modules/languages/bun.nix
    ../ekaos/modules/languages/c.nix
    ../ekaos/modules/languages/clojure.nix
    ../ekaos/modules/languages/cplusplus.nix
    ../ekaos/modules/languages/crystal.nix
    ../ekaos/modules/languages/cue.nix
    ../ekaos/modules/languages/deno.nix
    ../ekaos/modules/languages/elixir.nix
    ../ekaos/modules/languages/erlang.nix
    ../ekaos/modules/languages/fortran.nix
    ../ekaos/modules/languages/gawk.nix
    ../ekaos/modules/languages/gleam.nix
    ../ekaos/modules/languages/go.nix
    ../ekaos/modules/languages/guile.nix
    ../ekaos/modules/languages/hare.nix
    ../ekaos/modules/languages/haskell.nix
    ../ekaos/modules/languages/java.nix
    ../ekaos/modules/languages/javascript.nix
    ../ekaos/modules/languages/jsonnet.nix
    ../ekaos/modules/languages/julia.nix
    ../ekaos/modules/languages/kotlin.nix
    ../ekaos/modules/languages/lobster.nix
    ../ekaos/modules/languages/lua.nix
    ../ekaos/modules/languages/nim.nix
    ../ekaos/modules/languages/nix.nix
    ../ekaos/modules/languages/nodejs.nix
    ../ekaos/modules/languages/odin.nix
    ../ekaos/modules/languages/opentofu.nix
    ../ekaos/modules/languages/perl.nix
    ../ekaos/modules/languages/php.nix
    ../ekaos/modules/languages/purescript.nix
    ../ekaos/modules/languages/python.nix
    ../ekaos/modules/languages/r-lang.nix
    ../ekaos/modules/languages/ruby.nix
    ../ekaos/modules/languages/rust.nix
    ../ekaos/modules/languages/scala.nix
    ../ekaos/modules/languages/shell.nix
    ../ekaos/modules/languages/solidity.nix
    ../ekaos/modules/languages/tcl.nix
    ../ekaos/modules/languages/terraform.nix
    ../ekaos/modules/languages/texlive.nix
    ../ekaos/modules/languages/typst.nix
    ../ekaos/modules/languages/typescript.nix
    ../ekaos/modules/languages/unison.nix
    ../ekaos/modules/languages/vala.nix
    ../ekaos/modules/languages/zig.nix
  ];

  # Stub module providing the options that language modules write to.
  # In the full ekaos system these are defined by toplevel.nix and
  # shell-environment.nix; in the devshell context we provide lightweight
  # stubs and extract the collected values after evaluation.
  languageStubModule = {
    options.environment.packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Packages collected by language modules.";
    };

    options.environment.variables = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.str
          lib.types.path
          lib.types.package
        ]
      );
      default = { };
      description = "Environment variables collected by language modules.";
    };

    # Stub for per-user options (languages modules extend users.users)
    # In devshell context per-user config is unused, but the options must
    # exist so the module evaluates without errors.
    options.users.users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule { });
      default = { };
      description = "Stub for per-user options (unused in devshell context).";
    };
  };

  # Simple mkShell implementation (Phase 1 - basic version)
  mkShell =
    attrs:
    stdenv.mkDerivation (
      {
        name = "dev-shell";
        phases = [ "buildPhase" ];
        buildPhase = ''
          { echo "------------------------------------------------------------";
            echo " WARNING: the existence of this path is not guaranteed.";
            echo " It is an internal implementation detail for mkDevShell.";
            echo "------------------------------------------------------------";
            echo;
            # Record all build inputs as runtime dependencies
            export;
          } >> "$out"
        '';
        preferLocalBuild = true;
        shellHook = "";
      }
      // attrs
    );

in

{
  # Main function: Create a development shell with services
  mkDevShell =
    {
      # Shell name
      name ? "dev-shell",

      # Service and language configuration via modules
      modules ? [ ],

      # Traditional mkShell options
      packages ? [ ],
      shellHook ? "",
      buildInputs ? [ ],
      nativeBuildInputs ? [ ],
      propagatedBuildInputs ? [ ],
      propagatedNativeBuildInputs ? [ ],

      # Propagate all inputs from the given derivations
      inputsFrom ? [ ],

      # Environment variables to set in the shell (attrset of strings)
      env ? { },

      # process-compose specific options
      processCompose ? {
        tui = true;
        autoStart = false;
        logDir = "./.dev/logs";
        dataDir = "./.dev/data";
      },

      # Pass-through options for mkShell
      ...
    }@args:

    let
      # Evaluate the service modules (check = false ignores language options)
      servicesEval = lib.evalModules {
        modules = [
          { _module.check = false; }
          {
            options.services = serviceLib.mkServicesOption;
          }
        ]
        ++ modules;
      };

      # Extract enabled services
      services = servicesEval.config.services or { };
      enabledServices = lib.filterAttrs (_: cfg: cfg.enable or false) services;

      # Build the process-compose configuration
      processComposeConfig = pcTranslate.buildProcessComposeConfig enabledServices;

      # Use real process-compose package
      processComposePackage = pkgs.process-compose;

      # Create utility scripts
      utilities = import ./lib/utilities.nix {
        inherit lib pkgs processComposeConfig;
        processCompose = processComposePackage;
        inherit (processCompose) tui logDir dataDir;
      };

      # Evaluate language modules (check = false ignores service options)
      languagesEval = lib.evalModules {
        modules = [
          { _module.check = false; }
          languageStubModule
        ]
        ++ languageModuleFiles
        ++ modules;
        specialArgs = {
          inherit lib pkgs;
        };
      };

      # Extract packages and environment variables from language evaluation
      langPackages = languagesEval.config.environment.packages;
      langVariables = languagesEval.config.environment.variables;

      # Generate export statements for language environment variables
      langExports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: value: "export ${name}=${lib.escapeShellArg (toString value)}"
        ) langVariables
      );

      # Merge inputs from inputsFrom derivations (same logic as mkShell/to-dev-shell)
      mergeInputs =
        attr:
        (args.${attr} or [ ])
        ++ (lib.subtractLists inputsFrom (lib.flatten (lib.catAttrs attr inputsFrom)));

      mergedBuildInputs = mergeInputs "buildInputs";
      mergedNativeBuildInputs = mergeInputs "nativeBuildInputs";
      mergedPropagatedBuildInputs = mergeInputs "propagatedBuildInputs";
      mergedPropagatedNativeBuildInputs = mergeInputs "propagatedNativeBuildInputs";

      # Merge shellHooks from inputsFrom
      inputsFromShellHook = lib.concatStringsSep "\n" (
        lib.catAttrs "shellHook" (lib.reverseList inputsFrom)
      );

      # Generate export statements for env variables
      envExports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (n: v: "export ${n}=${lib.escapeShellArg (toString v)}") env
      );

      # Extract non-service options for mkShell
      shellArgs = builtins.removeAttrs args [
        "name"
        "modules"
        "packages"
        "buildInputs"
        "nativeBuildInputs"
        "propagatedBuildInputs"
        "propagatedNativeBuildInputs"
        "inputsFrom"
        "env"
        "shellHook"
        "processCompose"
      ];

      # Build the enhanced shellHook
      enhancedShellHook = ''
        # Create directories for services
        mkdir -p ${processCompose.logDir}
        mkdir -p ${processCompose.dataDir}

        ${lib.optionalString (env != { }) ''
          # Derivation environment variables
          ${envExports}
        ''}

        ${lib.optionalString (langVariables != { }) ''
          # Language environment variables
          ${langExports}
        ''}

        # Display service information
        echo "================================================"
        echo "Development Shell: ${name}"
        echo "================================================"
        ${lib.optionalString (enabledServices != { }) ''
          echo ""
          echo "Available services:"
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (svcName: _: "  echo \"  - ${svcName}\"") enabledServices
          )}
          echo ""
          echo "Service management commands:"
          echo "  pc-up       - Start all services (with TUI)"
          echo "  pc-down     - Stop all services"
          echo "  pc-status   - Show service status"
          echo "  pc-logs     - View all service logs"
          echo ""
        ''}
        echo "================================================"
        echo ""

        ${lib.optionalString (enabledServices != { }) ''
          # Auto-start services in detached mode
          echo "Starting services in the background..."
          ${processComposePackage}/bin/process-compose -f "$PROCESS_COMPOSE_CONFIG" up \
            --detached --tui=false \
            --log-file "${processCompose.logDir}/process-compose.log" \
            --unix-socket "${processCompose.dataDir}/process-compose.sock" \
            2>"${processCompose.logDir}/process-compose-startup.log" || \
            echo "WARNING: Failed to start services. Check ${processCompose.logDir}/process-compose-startup.log"
          echo "Services started. Use 'pc-status' to check, 'pc-down' to stop."
          echo ""

          # Stop services when the shell exits
          _pc_cleanup() {
            ${processComposePackage}/bin/process-compose -f "$PROCESS_COMPOSE_CONFIG" down \
              --unix-socket "${processCompose.dataDir}/process-compose.sock" \
              2>/dev/null || true
          }
          trap _pc_cleanup EXIT
        ''}

        # Shell hooks from inputsFrom derivations
        ${inputsFromShellHook}

        # User's custom shellHook
        ${shellHook}
      '';

    in
    mkShell (
      shellArgs
      // {
        inherit name;

        buildInputs =
          mergedBuildInputs
          ++ packages
          ++ langPackages
          ++ [ processComposePackage ]
          ++ (lib.attrValues utilities);

        nativeBuildInputs = mergedNativeBuildInputs;
        propagatedBuildInputs = mergedPropagatedBuildInputs;
        propagatedNativeBuildInputs = mergedPropagatedNativeBuildInputs;

        shellHook = enhancedShellHook;

        # Make process-compose config available as environment variable
        PROCESS_COMPOSE_CONFIG = "${processComposeConfig}";

        # Set data and log directories
        DEV_DATA_DIR = processCompose.dataDir;
        DEV_LOG_DIR = processCompose.logDir;
      }
    );
}

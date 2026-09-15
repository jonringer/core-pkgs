# runitTests - Module-based service testing framework
#
# Runs runit-supervised services in nix-build sandbox for service-to-service testing.
# Uses the services module system for declarative service configuration.
#
# Usage:
#   pkgs.runitTest {
#     name = "my-service-test";
#
#     modules = [
#       {
#         services.webserver = {
#           enable = true;
#           command = "${pkgs.python3}/bin/python3";
#           args = [ "-m" "http.server" "8080" ];
#         };
#       }
#     ];
#
#     testScript = ''
#       # Python test script (not bash!)
#       machine.wait_for_open_port(8080)
#       machine.succeed("curl http://localhost:8080")
#     '';
#   }

{ lib, pkgs }:

let
  inherit (lib)
    mapAttrsToList
    concatStringsSep
    optionalString
    ;

  # Import services module infrastructure
  serviceModule = import ../lib/service-module.nix { inherit lib pkgs; };

  # Build the runit test driver (Python)
  runitTestDriver = pkgs.callPackage ./runit-test-driver { };

  # Build a test that runs runit services and executes a test script
  #
  # Args:
  #   name: Test name
  #   modules: List of configuration modules (using services.* options)
  #   testScript: Python script to run after services start
  #   extraDependencies: Additional packages for test script (default: [])
  #   timeout: Maximum test duration in seconds (default: 120)
  mkRunitTest =
    {
      name,
      modules,
      testScript,
      extraDependencies ? [ ],
      timeout ? 120,
      ...
    }@args:
    let
      # Evaluate modules through the module system
      evaluated = lib.evalModules {
        modules = [
          {
            options.services = serviceModule.mkServicesOption;
          }
        ]
        ++ modules;
      };

      # Extract evaluated services
      services = evaluated.config.services;

      # Build service directories using the module system
      serviceDerivations = serviceModule.mkRunitServices services;

      # List of service names for iteration
      serviceNames = lib.attrNames serviceDerivations;

      # Build the runitTestHook
      runitTestHook = pkgs.callPackage ./runit-test-hook { };

      # Default dependencies for test scripts
      defaultDeps = with pkgs; [
        coreutils
        gnugrep
        sed
        curl
        netcat
      ];

      # All dependencies
      allDeps = defaultDeps ++ extraDependencies;

      # Setup phase: Create service directory and copy all services
      setupServices = ''
        echo "=== Setting up runit service directory ===" >&2

        # Create service directory
        export RUNIT_SERVICE_DIR="$TMPDIR/service"
        mkdir -p "$RUNIT_SERVICE_DIR"

        # Copy all service directories (not symlink, runit needs writable dirs)
        ${concatStringsSep "\n" (
          mapAttrsToList (name: deriv: ''
            echo "Copying service: ${name}" >&2
            cp -r ${deriv} "$RUNIT_SERVICE_DIR/${name}"
            chmod -R u+w "$RUNIT_SERVICE_DIR/${name}"
          '') serviceDerivations
        )}

        echo "Service directory ready: $RUNIT_SERVICE_DIR" >&2
        ls -la "$RUNIT_SERVICE_DIR" >&2
      '';

    in
    pkgs.stdenv.mkDerivation {
      name = "runit-test-${name}";

      # Required for Darwin localhost networking
      __darwinAllowLocalNetworking = true;

      nativeBuildInputs = [
        runitTestHook
        runitTestDriver
        pkgs.python3
      ]
      ++ allDeps;

      dontUnpack = true;
      dontBuild = true;

      # Setup services before check phase
      preCheck = ''
        ${setupServices}

        # Start runit supervisor
        runitTestStart

        # Give services a moment to start
        # (tests will use runitTestWaitPort to wait for specific ports)
        sleep 2
      '';

      # Run the test script (Python)
      checkPhase = ''
                runHook preCheck

                # Write Python test script to file
                cat > /build/test-script.py <<'PYTHON_TEST_SCRIPT'
        ${testScript}
        PYTHON_TEST_SCRIPT

                # Run Python test driver, capturing output to log file
                python3 -m runit_test_driver --testscript /build/test-script.py 2>&1 | tee "$RUNIT_LOG_DIR/test-driver.log"

                runHook postCheck
      '';

      # postCheck hook (includes runitTestStop from hook)
      # The runitTestHook automatically adds runitTestStop to postCheckHooks

      installPhase = ''
        # Create output marker
        mkdir -p $out
        echo "success" > $out/result

        # Copy logs if they exist
        if [ -d "$RUNIT_LOG_DIR" ]; then
          cp -r "$RUNIT_LOG_DIR" $out/logs
        fi
      '';

      doCheck = true;

      meta = {
        description = "Runit service test: ${name}";
        timeout = timeout;
      };

      # Increase build timeout
      maxBuildTime = timeout;
    };

in

{
  inherit mkRunitTest;

  # Alias for consistency with ekaosTest
  runitTest = mkRunitTest;
}

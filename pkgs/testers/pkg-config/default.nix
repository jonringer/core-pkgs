{
  lib,
  buildPackages,
  runCommand,
}:

{
  # Test function to verify pkg-config installation and optionally compile example code
  # Usage: testers.pkg-config.testInstall myPackage { modules = [ "foo" ]; example = ./example.c; }
  testInstall =
    package:
    {
      modules ? package.meta.pkgConfigModules or [ ],
      example ? null,
    }:
    runCommand "test-pkg-config-install-${package.pname or package.name}"
      {
        nativeBuildInputs = [
          buildPackages.stdenv.cc
          buildPackages.pkg-config
        ];
        buildInputs = [ package ];
        inherit modules;
        expectedInclude = lib.getInclude package;
        expectedLib = lib.getLib package;
      }
      (
        lib.optionalString (example != null) ''
          exampleSrc=${example}
        ''
        + ''
          set -e

          echo "Testing pkg-config installation for ${package.name}"
          echo "============================================"

          # Test each module (if modules are specified)
          if ((''${#modules[@]})); then
            for module in "''${modules[@]}"; do
            echo ""
            echo "Testing module: $module"

            # Check if module exists
            if ! pkg-config --exists "$module"; then
              echo "❌ ERROR: Module $module not found"
              echo ""
              echo "Available modules:"
              pkg-config --list-all
              exit 1
            fi

            # Get and display version
            version=$(pkg-config --modversion "$module")
            echo "  Version: $version"

            # Get and validate cflags
            cflags=$(pkg-config --cflags "$module")
            echo "  CFLAGS: $cflags"

            # Get and validate libs
            libs=$(pkg-config --libs "$module")
            echo "  LIBS: $libs"

            # Extract and validate include paths
            includePaths=$(pkg-config --cflags-only-I "$module" || echo "")
            if [ -n "$includePaths" ]; then
              echo "  Include paths: $includePaths"
              # Check if any include path matches the expected Nix include path
              foundInclude=false
              for path in $includePaths; do
                # Remove -I prefix
                cleanPath=''${path#-I}

                # Assert that the path exists
                if [ ! -d "$cleanPath" ]; then
                  echo "  ❌ ERROR: Include path does not exist: $cleanPath"
                  exit 1
                fi

                # Assert that the path is not empty
                if [ -z "$(ls -A "$cleanPath" 2>/dev/null)" ]; then
                  echo "  ❌ ERROR: Include path exists but is empty: $cleanPath"
                  exit 1
                fi

                # Check if this path is under the expected include directory
                if [[ "$cleanPath" == "$expectedInclude"* ]]; then
                  echo "  ✅ Include path matches Nix store: $cleanPath"
                  foundInclude=true
                  break
                fi
              done
              if [ "$foundInclude" = false ] && [ -d "$expectedInclude/include" ]; then
                echo "  ⚠️  WARNING: No include path matches expected Nix location: $expectedInclude/include"
              fi
            fi

            # Extract and validate library paths
            libPaths=$(pkg-config --libs-only-L "$module" || echo "")
            if [ -n "$libPaths" ]; then
              echo "  Library paths: $libPaths"
              # Check if any lib path matches the expected Nix lib path
              foundLib=false
              for path in $libPaths; do
                # Remove -L prefix
                cleanPath=''${path#-L}

                # Assert that the path exists
                if [ ! -d "$cleanPath" ]; then
                  echo "  ❌ ERROR: Library path does not exist: $cleanPath"
                  exit 1
                fi

                # Assert that the path is not empty
                if [ -z "$(ls -A "$cleanPath" 2>/dev/null)" ]; then
                  echo "  ❌ ERROR: Library path exists but is empty: $cleanPath"
                  exit 1
                fi

                # Check if this path is under the expected lib directory
                if [[ "$cleanPath" == "$expectedLib"* ]]; then
                  echo "  ✅ Library path matches Nix store: $cleanPath"
                  foundLib=true
                  break
                fi
              done
              if [ "$foundLib" = false ] && [ -d "$expectedLib/lib" ]; then
                echo "  ⚠️  WARNING: No library path matches expected Nix location: $expectedLib/lib"
              fi
            fi

            echo "  ✅ Module $module OK"
            done
          else
            echo "No pkg-config modules specified for testing"
            if [ -z "$exampleSrc" ]; then
              echo "ERROR: No modules or example provided - nothing to test"
              exit 1
            fi
          fi

          # If example source is provided, compile and link it
          if [ -n "$exampleSrc" ]; then
            echo ""
            echo "Compiling example: $exampleSrc"
            echo "--------------------------------"

            # Get combined flags for all modules
            if ((''${#modules[@]})); then
              allCflags=$(pkg-config --cflags "''${modules[@]}")
              allLibs=$(pkg-config --libs "''${modules[@]}")
              echo "Combined CFLAGS: $allCflags"
              echo "Combined LIBS: $allLibs"
            else
              allCflags=""
              allLibs=""
              echo "No modules specified - compiling without pkg-config flags"
            fi

            # Compile
            echo "Compiling..."
            if ! $CC $allCflags -c "$exampleSrc" -o example.o; then
              echo "❌ ERROR: Compilation failed"
              exit 1
            fi
            echo "  ✅ Compilation successful"

            # Link
            echo "Linking..."
            if ! $CC example.o $allLibs -o example; then
              echo "❌ ERROR: Linking failed"
              exit 1
            fi
            echo "  ✅ Linking successful"

            echo ""
            echo "✅ Example code compiled and linked successfully"
          fi

          echo ""
          echo "============================================"
          echo "✅ All pkg-config tests passed for ${package.name}"

          touch "$out"
        ''
      );
}

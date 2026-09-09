{ callPackage }:

{
  test-bash = callPackage (
    {
      lib,
      runCommandLocal,
      bash,
      coreutils,
      ksh,
      patchRcPathBash,
      shellcheck,
      zsh,
    }:
    runCommandLocal "patch-rc-path-bash-test"
      {
        nativeBuildInputs = [
          bash
          ksh
          patchRcPathBash
          shellcheck
          zsh
        ];
        meta = {
          description = "Package test of patchActivateBash";
        };
      }
      ''
        set -eu -o pipefail


        # Check the setup hook script

        echo "Running shellcheck against ${./test-sourcing-bash}"
        shellcheck -s bash --exclude SC1090 ${./test-sourcing-bash}
        shellcheck -s ksh --exclude SC1090 ${./test-sourcing-bash}


        # Test patching a blank file

        echo > blank.bash

        echo "Generating blank_patched.bash from blank.bash"
        cp blank.bash blank_patched.bash
        patchRcPathBash blank_patched.bash "$PWD/delta:$PWD/foxtrot"

        echo "Running shellcheck against blank_patched.bash"
        shellcheck -s bash blank_patched.bash
        shellcheck -s ksh blank_patched.bash

        echo "Testing in Bash if blank.bash and blank_patched.bash modifies PATH the same way"
        bash ${./test-sourcing-bash} ./blank.bash ./blank_patched.bash

        echo "Testing in Ksh if blank.bash and blank_patched.bash modifies PATH the same way"
        ksh ${./test-sourcing-bash} "$PWD/blank.bash" "$PWD/blank_patched.bash"

        echo "Testing in Zsh if blank.bash and blank_patched.bash modifies PATH the same way"
        zsh ${./test-sourcing-bash} ./blank.bash ./blank_patched.bash


        # Test patching a silent command

        echo "dirname / > /dev/null" > silent_command.bash

        echo "Generating silent_command_patched.bash from silent_command.bash"
        cp silent_command.bash silent_command_patched.bash
        patchRcPathBash silent_command_patched.bash "${coreutils}/bin"

        echo "Running shellcheck against silent_command_patched.bash"
        shellcheck -s bash silent_command_patched.bash

        echo "Testing in Bash if silent_command_patched.bash get sourced without error"
        bash -eu -o pipefail -c ". ./silent_command_patched.bash"

        echo "Testing in Ksh if silent_command_patched.bash get sourced without error"
        ksh -eu -o pipefail -c ". ./silent_command_patched.bash"

        echo "Testing in Zsh if silent_command_patched.bash get sourced without error"
        zsh -eu -o pipefail -c ". ./silent_command_patched.bash"


        # Check the sample source

        echo "Running shellcheck against sample_source.bash"
        shellcheck -s bash ${./sample_source.bash}
        shellcheck -s ksh ${./sample_source.bash}


        # Test patching the sample source

        cp ${./sample_source.bash} sample_source_patched.bash
        chmod u+w sample_source_patched.bash

        echo "Generating sample_source_patched.bash from ./sample_source.bash"
        patchRcPathBash sample_source_patched.bash "$PWD/delta:$PWD/foxtrot"

        echo "Running shellcheck against sample_source_patched.bash"
        shellcheck -s bash sample_source_patched.bash

        echo "Testing in Bash if sample_source.bash and sample_source_patched.bash modifies PATH the same way"
        bash ${./test-sourcing-bash} ${./sample_source.bash} ./sample_source_patched.bash

        echo "Testing in Ksh if sample_source.bash and sample_source_patched.bash modifies PATH the same way"
        ksh ${./test-sourcing-bash} ${./sample_source.bash} "$PWD/sample_source_patched.bash"

        echo "Testing in Zsh if sample_source.bash and sample_source_patched.bash modifies PATH the same way"
        zsh ${./test-sourcing-bash} ${./sample_source.bash} ./sample_source_patched.bash


        # Test double-patching the sample source

        echo "Patching again sample_source_patched.bash"
        patchRcPathBash sample_source_patched.bash "$PWD/foxtrot:$PWD/golf"

        echo "Running shellcheck against sample_source_patched.bash"
        shellcheck -s bash sample_source_patched.bash
        shellcheck -s ksh sample_source_patched.bash

        echo "Testing in Bash if sample_source.bash and sample_source_patched.bash modifies PATH the same way"
        bash ${./test-sourcing-bash} ${./sample_source.bash} ./sample_source_patched.bash

        echo "Testing in Ksh if sample_source.bash and sample_source_patched.bash modifies PATH the same way"
        ksh ${./test-sourcing-bash} ${./sample_source.bash} "$PWD/sample_source_patched.bash"

        echo "Testing in Zsh if sample_source.bash and sample_source_patched.bash modifies PATH the same way"
        zsh ${./test-sourcing-bash} ${./sample_source.bash} ./sample_source_patched.bash


        # Create a dummy output
        touch "$out"
      ''
  ) { };

  test-csh = callPackage (
    {
      lib,
      runCommandLocal,
      sed,
      coreutils,
      patchRcPathCsh,
      tcsh,
    }:
    runCommandLocal "patch-rc-path-csh-test"
      {
        nativeBuildInputs = [
          patchRcPathCsh
          tcsh
        ];
        meta = {
          description = "Package test of patchActivateCsh";
        };
      }
      ''
        set -eu -o pipefail


        # Test patching a blank file

        echo > blank.csh

        echo "Generating blank_patched.csh from blank.csh"
        cp blank.csh blank_patched.csh
        patchRcPathCsh blank_patched.csh "$PWD/delta:$PWD/foxtrot"

        echo "Testing in Csh if blank.csh and blank_patched.csh modifies PATH the same way"
        tcsh -e ${./test-sourcing-csh} blank.csh blank_patched.csh


        # Test patching a silent command file

        echo "dirname / > /dev/null" > silent_command.csh

        echo "Generating silent_command_patched.csh from silent_command.csh"
        cp silent_command.csh silent_command_patched.csh
        patchRcPathCsh silent_command_patched.csh "${coreutils}/bin"

        echo "Testing in Csh if silent_command_patched.csh get sourced without error"
        tcsh -e -c "source silent_command_patched.csh"


        # Generate the sample source

        substitute ${./sample_source.csh.in} sample_source.csh --replace @sed@ ${sed}/bin/sed
        chmod u+rw sample_source.csh


        # Test patching the sample source

        echo "Generating sample_source_patched.csh from sample_source.csh"
        cp sample_source.csh sample_source_patched.csh
        chmod u+w sample_source_patched.csh
        patchRcPathCsh sample_source_patched.csh "$PWD/delta:$PWD/foxtrot"

        echo "Testing in Csh if sample_source.csh and sample_source_patched.csh modifies PATH the same way"
        tcsh -e ${./test-sourcing-csh} sample_source.csh sample_source_patched.csh


        # Test double-patching the sample source

        echo "Patching again sample_source_patched.csh from sample_source.csh"
        patchRcPathCsh sample_source_patched.csh "$PWD/foxtrot:$PWD/golf"

        echo "Testing in Csh if sample_source.csh and sample_source_patched.csh modifies PATH the same way"
        tcsh -e ${./test-sourcing-csh} sample_source.csh sample_source_patched.csh


        # Create a dummy output
        touch "$out"
      ''
  ) { };

  test-fish = callPackage (
    {
      lib,
      runCommandLocal,
      fish,
      coreutils,
      patchRcPathFish,
    }:
    runCommandLocal "patch-rc-path-fish-test"
      {
        nativeBuildInputs = [
          fish
          patchRcPathFish
        ];
        meta = {
          description = "Package test of patchActivateFish";
        };
      }
      ''
        set -eu -o pipefail


        # Test patching a blank file

        echo > blank.fish

        echo "Generating blank_patched.fish from blank.fish"
        cp blank.fish blank_patched.fish
        patchRcPathFish blank_patched.fish "$PWD/delta:$PWD/foxtrot"

        echo "Testing in Fish if blank.fish and blank_patched.fish modifies PATH the same way"
        HOME_TEMP="$(mktemp -d temporary_home_XXXXXX)"
        HOME="$HOME_TEMP" fish ${./test-sourcing-fish} blank.fish blank_patched.fish
        rm -r "$HOME_TEMP"


        # Test patching a silent command file

        echo "dirname / > /dev/null" > silent_command.fish

        echo "Generating silent_command_patched.fish from silent_command.fish"
        cp silent_command.fish silent_command_patched.fish
        patchRcPathFish silent_command_patched.fish "${coreutils}/bin"

        echo "Testing in Fish if silent_command_patched.fish get sourced without error"
        HOME_TEMP="$(mktemp -d temporary_home_XXXXXX)"
        HOME="$HOME_TEMP" fish -c "source silent_command_patched.fish"
        rm -r "$HOME_TEMP"


        # Test patching the sample source

        cp ${./sample_source.fish} sample_source_patched.fish
        chmod u+w sample_source_patched.fish

        echo "Generating sample_source_patched.fish from ${./sample_source.fish}"
        patchRcPathFish sample_source_patched.fish "$PWD/delta:$PWD/foxtrot"
        echo "Testing in Fish if sample_source.fish and sample_source_patched.fish modifies PATH the same way"
        HOME_TEMP="$(mktemp -d temporary_home_XXXXXX)"
        HOME="$HOME_TEMP" fish ${./test-sourcing-fish} ${./sample_source.fish} sample_source_patched.fish
        rm -r "$HOME_TEMP"


        # Test double-patching the sample source

        echo "Patching again sample_source_patched.fish from ${./sample_source.fish}"
        patchRcPathFish sample_source_patched.fish "$PWD/foxtrot:$PWD/golf"

        echo "Testing in Fish if sample_source.fish and sample_source_patched.fish modifies PATH the same way"
        HOME_TEMP="$(mktemp -d temporary_home_XXXXXX)"
        HOME="$HOME_TEMP" fish ${./test-sourcing-fish} ${./sample_source.fish} sample_source_patched.fish
        rm -r "$HOME_TEMP"


        # Create a dummy output
        touch "$out"
      ''
  ) { };

  test-posix = callPackage (
    {
      lib,
      runCommandLocal,
      bash,
      dash,
      sed,
      coreutils,
      ksh,
      patchRcPathPosix,
      shellcheck,
    }:
    runCommandLocal "patch-rc-path-posix-test"
      {
        nativeBuildInputs = [
          bash
          dash
          ksh
          patchRcPathPosix
          shellcheck
        ];
        meta = {
          description = "Package test of patchActivatePosix";
        };
      }
      ''
        set -eu -o pipefail


        # Check the setup hook script

        echo "Running shellcheck against ${./test-sourcing-posix}"
        shellcheck -s sh --exclude SC1090 ${./test-sourcing-posix}
        shellcheck -s dash --exclude SC1090 ${./test-sourcing-posix}


        # Test patching a blank file

        echo > blank.sh

        echo "Generating blank_patched.sh from blank.sh"
        cp blank.sh blank_patched.sh
        patchRcPathPosix blank_patched.sh "$PWD/delta:$PWD/foxtrot"

        echo "Running shellcheck against blank_patched.sh"
        shellcheck -s sh blank_patched.sh
        shellcheck -s dash blank_patched.sh

        echo "Testing in Bash if blank.sh and blank_patched.sh modifies PATH the same way"
        bash --posix ${./test-sourcing-posix} ./blank.sh ./blank_patched.sh

        echo "Testing in Dash if blank.sh and blank_patched.sh modifies PATH the same way"
        dash ${./test-sourcing-posix} ./blank.sh ./blank_patched.sh

        echo "Testing in Ksh if ./blank.sh and ./blank_patched.sh modifies PATH the same way"
        ksh ${./test-sourcing-posix} "$PWD/blank.sh" "$PWD/blank_patched.sh"


        # Test patching a silent command file

        echo "dirname / > /dev/null" > silent_command.sh

        echo "Generating silent_command_patched.sh from silent_command.sh"
        cp silent_command.sh silent_command_patched.sh
        patchRcPathPosix silent_command_patched.sh "${coreutils}/bin"

        echo "Running shellcheck against silent_command_patched.sh"
        shellcheck -s sh silent_command_patched.sh
        shellcheck -s dash silent_command_patched.sh

        echo "Testing in Bash if silent_command_patched.sh get sourced without error"
        bash --posix -eu -c ". ./silent_command_patched.sh"

        echo "Testing in Dash if silent_command_patched.sh get sourced without error"
        dash -eu -c ". ./silent_command_patched.sh"

        echo "Testing in Ksh if silent_command_patched.sh get sourced without error"
        ksh -eu -c ". $PWD/silent_command_patched.sh"


        # Generate the sample source "$PWD/delta:$PWD/foxtrot" "$PWD/delta:$PWD/foxtrot"

        substitute ${./sample_source.sh.in} sample_source.sh --replace @sed@ ${sed}/bin/sed
        chmod u+rw sample_source.sh


        # Check the sample source

        echo "Running shellcheck against sample_source.sh"
        shellcheck -s sh sample_source.sh
        shellcheck -s dash sample_source.sh


        # Test patching the sample source

        echo "Generating sample_source_patched.sh from sample_source.sh"
        cp sample_source.sh sample_source_patched.sh
        chmod u+w sample_source_patched.sh
        patchRcPathPosix sample_source_patched.sh "$PWD/delta:$PWD/foxtrot"

        echo "Running shellcheck against sample_source_patched.sh"
        shellcheck -s sh sample_source_patched.sh
        shellcheck -s dash sample_source_patched.sh

        echo "Testing in Bash if sample_source.bash and sample_source_patched.bash modifies PATH the same way"
        bash --posix ${./test-sourcing-posix} "./sample_source.sh" "./sample_source_patched.sh"

        echo "Testing in Dash if sample_source.sh and sample_source_patched.sh modifies PATH the same way"
        dash ${./test-sourcing-posix} "./sample_source.sh" "./sample_source_patched.sh"

        echo "Testing in Ksh if sample_source.sh and sample_source_patched.sh modifies PATH the same way"
        ksh ${./test-sourcing-posix} "$PWD/sample_source.sh" "$PWD/sample_source_patched.sh"


        # Test double-patching the sample source

        echo "Patching again sample_source_patched.sh"
        patchRcPathPosix sample_source_patched.sh "$PWD/foxtrot:$PWD/golf"

        echo "Running shellcheck against sample_source_patched.sh"
        shellcheck -s sh sample_source_patched.sh
        shellcheck -s dash sample_source_patched.sh

        echo "Testing in Bash if sample_source.bash and sample_source_patched.bash modifies PATH the same way"
        bash --posix ${./test-sourcing-posix} "./sample_source.sh" "./sample_source_patched.sh"

        echo "Testing in Dash if sample_source.sh and sample_source_patched.sh modifies PATH the same way"
        dash ${./test-sourcing-posix} "./sample_source.sh" "./sample_source_patched.sh"

        echo "Testing in Ksh if sample_source.sh and sample_source_patched.sh modifies PATH the same way"
        ksh ${./test-sourcing-posix} "$PWD/sample_source.sh" "$PWD/sample_source_patched.sh"


        # Create a dummy output
        touch "$out"
      ''
  ) { };
}

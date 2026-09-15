{
  lib,
  callPackage,
  makeSetupHook,
  sed,
}:
let
  tests = import ./test { inherit callPackage; };
in
{
  patchRcPathBash = makeSetupHook {
    name = "patch-rc-path-bash";
    meta = {
      description = "Setup-hook to inject source-time PATH prefix to a Bash/Ksh/Zsh script";
    };
    passthru.tests = {
      inherit (tests) test-bash;
    };
  } ./patch-rc-path-bash.sh;
  patchRcPathCsh = makeSetupHook {
    name = "patch-rc-path-csh";
    substitutions = {
      sed = "${sed}/bin/sed";
    };
    meta = {
      description = "Setup-hook to inject source-time PATH prefix to a Csh script";
    };
    passthru.tests = {
      inherit (tests) test-csh;
    };
  } ./patch-rc-path-csh.sh;
  patchRcPathFish = makeSetupHook {
    name = "patch-rc-path-fish";
    meta = {
      description = "Setup-hook to inject source-time PATH prefix to a Fish script";
    };
    passthru.tests = {
      inherit (tests) test-fish;
    };
  } ./patch-rc-path-fish.sh;
  patchRcPathPosix = makeSetupHook {
    name = "patch-rc-path-posix";
    substitutions = {
      sed = "${sed}/bin/sed";
    };
    meta = {
      description = "Setup-hook to inject source-time PATH prefix to a POSIX shell script";
    };
    passthru.tests = {
      inherit (tests) test-posix;
    };
  } ./patch-rc-path-posix.sh;
}

{
  lib,
  stdenv,
  makeSetupHook,
}:
deploymentTarget:
makeSetupHook {
  name = "darwin-deployment-target-hook-${deploymentTarget}";
  substitutions = {
    darwinMinVersionVariable = lib.escapeShellArg stdenv.hostPlatform.darwinMinVersionVariable;
    deploymentTarget = lib.escapeShellArg deploymentTarget;
  };
  meta.license = lib.licenses.mit;
} ./setup-hook.sh

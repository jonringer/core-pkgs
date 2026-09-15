{
  makeSetupHook,
  findutils,
  pkg-config,
}:

makeSetupHook {
  name = "validate-pkg-config";
  propagatedBuildInputs = [
    findutils
    pkg-config
  ];
} ./validate-pkg-config.sh

{
  makeSetupHook,
  auto-patchelf,
  bintools,
  stdenv,
}:

makeSetupHook {
  name = "auto-patchelf-hook";
  propagatedBuildInputs = [
    auto-patchelf
    bintools
  ];
  substitutions = {
    hostPlatform = stdenv.hostPlatform.config;
  };
} ./auto-patchelf.sh

{
  lib,
  targetPackages,
  makeSetupHook,
}:

makeSetupHook {
  name = "fix-darwin-dylib-names-hook";
  substitutions = { inherit (targetPackages.stdenv.cc) targetPrefix; };
  meta.platforms = lib.platforms.darwin;
} ./fix-darwin-dylib-names.sh

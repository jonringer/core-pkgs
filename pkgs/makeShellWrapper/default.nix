{
  makeSetupHook,
  dieHook,
  targetPackages,
}:

makeSetupHook {
  name = "make-shell-wrapper-hook";
  propagatedBuildInputs = [ dieHook ];
  substitutions = {
    # targetPackages.runtimeShell only exists when pkgs == targetPackages (when targetPackages is not  __raw)
    shell =
      if targetPackages ? runtimeShell then
        targetPackages.runtimeShell
      else
        throw "makeWrapper/makeShellWrapper must be in nativeBuildInputs";
  };
} ./make-wrapper.sh

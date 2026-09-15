{
  makeSetupHook,
  replaceVars,
  patchelf,
}:

makeSetupHook
  {
    name = "generate-ld-cache-hook";
    # TODO: Remove once makeSetupHook defaults __structuredAttrs to true.
    __structuredAttrs = true;
  }
  (
    replaceVars ./generate-ld-cache.sh {
      patchelf = "${patchelf}/bin/patchelf";
    }
  )

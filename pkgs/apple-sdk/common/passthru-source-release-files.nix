{ lib, sourceRelease }:

self: super: {
  passthru = super.passthru or { } // {
    sourceRelease =
      name:
      lib.warn
        "`apple-sdk.sourceRelease` is deprecated and is now an alias for `sourceRelease`. Please use `sourceRelease` directly."
        sourceRelease
        name;
  };
}

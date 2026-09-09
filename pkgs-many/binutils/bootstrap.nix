# Keep bootstrap derivations while refreshing variants in the final package scope.
previous: current:
let
  package = previous.overrideAttrs (old: {
    passthru =
      old.passthru
      // variants
      // {
        inherit variants;
      }
      // (
        if old.passthru ? bintools then
          {
            noLibc = current.noLibc.override { bintools = old.passthru.bintools; };
            unwrapped = import ./bootstrap.nix old.passthru.bintools current.unwrapped;
          }
        else
          { }
      );
  });
  variants = builtins.mapAttrs (
    _: value: if value.variantArgs.variant == previous.variantArgs.variant then package else value
  ) current.variants;
in
package

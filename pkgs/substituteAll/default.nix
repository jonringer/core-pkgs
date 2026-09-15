{ lib, stdenvNoCC }:

/**
  `substituteAll` is a thin wrapper around the [bash function `substituteAll`](https://nixos.org/manual/nixpkgs/stable/#fun-substituteAll)
  in the stdenv. It writes the file `src` to `$out`, replacing any occurrence
  of `@varName@` with the value of the attribute `varName` from the call's
  arguments (or from the inheritance of the derivation's environment).

  Unlike `replaceVars`, this is the legacy interface kept for compatibility
  with third-party packages: it does NOT fail on unsubstituted `@name@`
  occurrences. Prefer `replaceVars` for new code.

  # Inputs

  `src` ([Store Path](https://nixos.org/manual/nix/latest/store/store-path.html#store-path) String)
  : The file in which to substitute variables.

  `dir` (String, optional)
  : Sub directory under `$out` where the result should be written.

  `isExecutable` (Boolean, optional)
  : Whether to chmod +x the result.

  Other attributes are passed through to `stdenvNoCC.mkDerivation` *and*
  exported as environment variables visible to `substituteAll` (which is how
  the `@var@` replacements get their values).

  # Example

  ```nix
  substituteAll {
    src = ./greeting.txt;
    name = "greeting.txt";
    world = "hello";
  }
  ```
*/
args@{
  src,
  ...
}:

stdenvNoCC.mkDerivation (
  {
    name = if args ? name then args.name else baseNameOf (toString src);
    inherit src;
    preferLocalBuild = true;
    allowSubstitutes = false;
    # `substitutions` is a known mkDerivation conflict point and the stdenv's
    # `substituteAll` reads variables straight from the environment, so we
    # don't need to do anything special here.
    builder = ./substitute-all-builder.sh;
  }
  // builtins.removeAttrs args [ "src" ]
)

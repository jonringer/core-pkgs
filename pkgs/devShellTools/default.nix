{ lib }:

{
  # Convert a Nix value to a shell-safe string representation.
  valueToString =
    x:
    if builtins.isList x then
      lib.concatMapStringsSep " " (lib.self or (throw "devShellTools")).valueToString x
    else if builtins.isPath x then
      "${x}"
    else if builtins.isString x then
      x
    else if builtins.isInt x then
      toString x
    else if builtins.isBool x then
      lib.boolToString x
    else if x == null then
      ""
    else if builtins.isFloat x then
      lib.strings.floatToString x
    else if builtins.isAttrs x && x ? outPath then
      "${x}"
    else
      throw "devShellTools.valueToString: cannot convert ${builtins.typeOf x} to string";

  # Extract environment variables from a derivation's input attributes,
  # excluding internal/structural attributes that are not environment variables.
  unstructuredDerivationInputEnv =
    { drvAttrs }:
    let
      structuredAttrs = [
        "allowedReferences"
        "allowedRequisites"
        "args"
        "builder"
        "disallowedReferences"
        "disallowedRequisites"
        "name"
        "nativeBuildInputs"
        "depsBuildBuild"
        "depsBuildBuildPropagated"
        "depsBuildTarget"
        "depsBuildTargetPropagated"
        "depsHostHost"
        "depsHostHostPropagated"
        "depsTargetTarget"
        "depsTargetTargetPropagated"
        "buildInputs"
        "propagatedBuildInputs"
        "propagatedNativeBuildInputs"
        "outputs"
        "patches"
        "phases"
        "preferLocalBuild"
        "allowSubstitutes"
        "system"
        "__structuredAttrs"
        "__ignoreNulls"
      ];
    in
    removeAttrs drvAttrs structuredAttrs;

  # Create environment variables for derivation outputs.
  derivationOutputEnv =
    {
      outputList,
      outputMap,
    }:
    let
      outputVars = builtins.listToAttrs (
        map (output: {
          name = output;
          value = builtins.unsafeDiscardStringContext outputMap.${output};
        }) outputList
      );
    in
    outputVars;
}

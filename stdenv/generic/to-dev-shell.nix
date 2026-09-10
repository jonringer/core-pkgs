lib:

originalArgs:

# Extract shell-relevant information from a mkDerivation's derivationArg
# and merge it with user-supplied overrides, producing an attrset
# suitable for mkDevShell.
{
  name ? if originalArgs ? name then "${originalArgs.name}-dev-shell" else "dev-shell",
  # a list of packages to add to the shell environment
  packages ? [ ],
  # propagate all the inputs from the given derivations
  inputsFrom ? [ ],
  buildInputs ? [ ],
  nativeBuildInputs ? [ ],
  propagatedBuildInputs ? [ ],
  propagatedNativeBuildInputs ? [ ],
  shellHook ? "",
  modules ? [ ],
  env ? { },
  ...
}@attrs:
let
  # Merge original derivation inputs with user-supplied overrides
  mergeInputs =
    attrName:
    (originalArgs.${attrName} or [ ])
    ++ (attrs.${attrName} or [ ])
    ++ (lib.subtractLists inputsFrom (lib.flatten (lib.catAttrs attrName inputsFrom)));

  # Attrs from derivationArg that are build infrastructure, not environment
  # variables.  Anything not in this set AND string/path-valued will be
  # forwarded as an env var to the dev shell.
  infrastructureAttrs = [
    "name"
    "pname"
    "version"
    "builder"
    "args"
    "system"
    "outputs"
    "out"
    "src"
    "srcs"
    "sourceRoot"
    "setSourceRoot"
    "stdenv"
    "buildInputs"
    "nativeBuildInputs"
    "propagatedBuildInputs"
    "propagatedNativeBuildInputs"
    "depsBuildBuild"
    "depsBuildBuildPropagated"
    "depsBuildTarget"
    "depsBuildTargetPropagated"
    "depsHostHost"
    "depsHostHostPropagated"
    "depsTargetTarget"
    "depsTargetTargetPropagated"
    "shellHook"
    "patches"
    "patchFlags"
    "doCheck"
    "doInstallCheck"
    "strictDeps"
    "userHook"
    "__ignoreNulls"
    "__structuredAttrs"
    "__contentAddressed"
    "outputHashAlgo"
    "outputHashMode"
    "outputHash"
    "preferLocalBuild"
    "allowSubstitutes"
    "enableParallelBuilding"
    "enableParallelChecking"
    "enableParallelInstalling"
    "meta"
    "passthru"
    "pos"
    "separateDebugInfo"
    "hardeningEnable"
    "hardeningDisable"
    "NIX_HARDENING_ENABLE"
    "requiredSystemFeatures"
    "__darwinAllowLocalNetworking"
    "__sandboxProfile"
    "__propagatedSandboxProfile"
    "__impureHostDeps"
    "__propagatedImpureHostDeps"
    "allowedImpureDLLs"
    "outputChecks"
    "disallowedReferences"
    "disallowedRequisites"
    "allowedReferences"
    "allowedRequisites"
    "cmakeFlags"
    "mesonFlags"
    "configureFlags"
    "configurePlatforms"
    "makeFlags"
    "makefile"
    "installFlags"
    "installTargets"
    "dontInstall"
    "dontBuild"
    "dontConfigure"
    "dontFixup"
    "dontPatchShebangs"
    "dontPatchELF"
    "dontStrip"
    "forceShare"
    "setupHook"
    "setupHooks"
    "passAsFile"
  ];

  # Phase hooks and scripts (pre/post hooks, phase definitions, configure
  # scripts, etc.) are build-time concerns and should not leak as env vars.
  isPhaseAttr =
    name:
    lib.hasPrefix "pre" name
    || lib.hasPrefix "post" name
    || lib.hasSuffix "Phase" name
    || lib.hasSuffix "Phases" name
    || lib.hasSuffix "Hook" name
    || lib.hasSuffix "Script" name
    || lib.hasSuffix "Flags" name;

  # Environment variables from the original derivation (everything that's
  # a string and not infrastructure — these are typically set via `env` or
  # as top-level attrs in mkDerivation).
  originalEnv = lib.filterAttrs (
    n: v:
    !(builtins.elem n infrastructureAttrs)
    && !(isPhaseAttr n)
    && (builtins.isString v || builtins.isPath v)
  ) originalArgs;

  rest = builtins.removeAttrs attrs [
    "name"
    "packages"
    "inputsFrom"
    "buildInputs"
    "nativeBuildInputs"
    "propagatedBuildInputs"
    "propagatedNativeBuildInputs"
    "shellHook"
    "modules"
    "env"
  ];
in
{
  inherit name modules;

  buildInputs = mergeInputs "buildInputs";
  nativeBuildInputs = packages ++ (mergeInputs "nativeBuildInputs");
  propagatedBuildInputs = mergeInputs "propagatedBuildInputs";
  propagatedNativeBuildInputs = mergeInputs "propagatedNativeBuildInputs";

  inherit inputsFrom shellHook;

  # Merge original derivation env vars with user-supplied env
  env = originalEnv // env;
}
// rest

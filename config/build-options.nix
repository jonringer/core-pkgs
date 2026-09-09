{ lib, ... }:

let
  inherit (lib)
    mkOption
    types
    ;

  mkMassRebuild =
    args:
    mkOption (
      lib.removeAttrs args [ "feature" ]
      // {
        type = args.type or (types.uniq types.bool);
        default = args.default or false;
        description = (
          (args.description or ''
            Whether to ${args.feature} while building nixpkgs packages.
          ''
          )
          + ''
            Changing the default may cause a mass rebuild.
          ''
        );
      }
    );

in
{
  options = {

    # Internal stuff

    # Hide built-in module system options from docs.
    _module.args = mkOption {
      internal = true;
    };

    warnings = mkOption {
      type = types.listOf types.str;
      default = [ ];
      internal = true;
    };

    assertions = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            assertion = mkOption { type = types.bool; };
            message = mkOption { type = types.str; };
          };
        }
      );
      default = [ ];
      internal = true;
    };

    inHydra = mkOption {
      type = types.bool;
      default = false;
      internal = true;
    };

    replaceBootstrapFiles = mkMassRebuild {
      type = types.functionTo (types.attrsOf (types.either types.package types.path));
      default = lib.id;
      defaultText = lib.literalExpression "lib.id";
      description = "Replace the bootstrap files used to construct the standard environment.";
    };

    # Config options

    warnUndeclaredOptions = mkOption {
      description = "Whether to warn when `config` contains an unrecognized attribute.";
      type = types.bool;
      default = false;
    };

    doCheckByDefault = mkMassRebuild {
      feature = "run `checkPhase` by default";
    };

    configurePlatformsByDefault = mkMassRebuild {
      feature = "set `configurePlatforms` to `[\"build\" \"host\"]` by default";
    };

    contentAddressedByDefault = mkMassRebuild {
      feature = "set `__contentAddressed` to true by default";
    };

    cudaSupport = mkMassRebuild {
      feature = "build packages with CUDA support by default";
    };

    rocmSupport = mkMassRebuild {
      feature = "build packages with ROCm support by default";
    };
  };
}

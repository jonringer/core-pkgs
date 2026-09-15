{ lib, config, ... }:

let
  inherit (lib)
    literalExpression
    mkOption
    types
    ;
in
{
  options = {
    aliases = {
      nixpkgs = mkOption {
        type = types.bool;
        default = config.allowAliases;
        description = ''
          Whether to expose old attribute names for compatibility.

          The recommended setting is to enable this, as it
          improves backward compatibility, easing updates.

          The only reason to disable aliases is for continuous
          integration purposes. For instance, Nixpkgs should
          not depend on aliases in its internal code. Projects
          that aren't Nixpkgs should be cautious of instantly
          removing all usages of aliases, as migrating too soon
          can break compatibility with the stable Nixpkgs releases.
        '';
      };
    };

    # Backward-compatible alias for config.aliases.nixpkgs.
    allowAliases = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Deprecated alias for `aliases.nixpkgs`.
      '';
    };

    allowUnfree = mkOption {
      type = types.bool;
      default = false;
      # getEnv part is in check-meta.nix
      defaultText = literalExpression ''false || builtins.getEnv "NIXPKGS_ALLOW_UNFREE" == "1"'';
      description = ''
        Whether to allow unfree packages.

        See [Installing unfree packages](https://nixos.org/manual/nixpkgs/stable/#sec-allow-unfree) in the NixOS manual.
      '';
    };

    allowBroken = mkOption {
      type = types.bool;
      default = false;
      # getEnv part is in check-meta.nix
      defaultText = literalExpression ''false || builtins.getEnv "NIXPKGS_ALLOW_BROKEN" == "1"'';
      description = ''
        Whether to allow broken packages.

        See [Installing broken packages](https://nixos.org/manual/nixpkgs/stable/#sec-allow-broken) in the NixOS manual.
      '';
    };

    allowUnsupportedSystem = mkOption {
      type = types.bool;
      default = false;
      # getEnv part is in check-meta.nix
      defaultText = literalExpression ''false || builtins.getEnv "NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM" == "1"'';
      description = ''
        Whether to allow unsupported packages.

        See [Installing packages on unsupported systems](https://nixos.org/manual/nixpkgs/stable/#sec-allow-unsupported-system) in the NixOS manual.
      '';
    };

    allowVariants = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to expose the nixpkgs variants.

        Variants are instances of the current nixpkgs instance with different stdenvs or other applied options.
        This allows for using different toolchains, libcs, or global build changes across nixpkgs.
        Disabling can ensure nixpkgs is only building for the platform which you specified.
      '';
    };

    checkMeta = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to check that the `meta` attribute of derivations are correct during evaluation time.
      '';
    };

    hashedMirrors = mkOption {
      type = types.listOf types.str;
      # This does not exist for ekapkgs yet
      default = [ ];
      description = ''
        The set of content-addressed/hashed mirror URLs used by [`pkgs.fetchurl`](#sec-pkgs-fetchers-fetchurl).
        In case `pkgs.fetchurl` can't download from the given URLs,
        it will try the hashed mirrors based on the expected output hash.
        See [`copy-tarballs.pl`](https://github.com/NixOS/nixpkgs/blob/a2d829eaa7a455eaa3013c45f6431e705702dd46/maintainers/scripts/copy-tarballs.pl)
        for more details on how hashed mirrors are constructed.
      '';
    };

    handleEvalIssue = mkOption {
      type = types.functionTo (types.functionTo types.unspecified);
      description = ''
        A hook deciding what to do when `check-meta` refuses a package.

        It is passed the reason (`"unknown-meta"`, `"broken"`, `"unfree"`,
        `"unsupported"`, ...) and the rendered message, and whatever it
        returns is forced in place of the default `throw`. This lets a caller
        distinguish a malformed `meta`, which is always a mistake, from a
        package correctly declining to evaluate on this system.

        Left unset, every rejection throws.
      '';
      # `check-meta` dispatches on `config ? handleEvalIssue`, which a declared
      # option always satisfies, so the throw has to live in the default.
      default = _reason: msg: throw msg;
      defaultText = literalExpression "reason: msg: throw msg";
      example = literalExpression ''
        {
          handleEvalIssue =
            reason: msg: if reason == "unknown-meta" then abort msg else throw msg;
        }
      '';
    };

    rewriteURL = mkOption {
      type = types.functionTo (types.nullOr types.str);
      description = ''
        A hook to rewrite/filter URLs before they are fetched.

        The function is passed the URL as a string, and is expected to return a new URL, or null if the given URL should not be attempted.

        This function is applied _prior_ to resolving mirror:// URLs.

        The intended use is to allow URL rewriting to insert company-internal mirrors, or work around company firewalls and similar network restrictions.
      '';
      default = lib.id;
      defaultText = literalExpression "(url: url)";
      example = literalExpression ''
        {
          # Use Nix like it's 2024! ;-)
          rewriteURL = url: "https://web.archive.org/web/2024/''${url}";
        }
      '';
    };

    problems = (import ../stdenv/generic/problems.nix { inherit lib; }).configOptions;
  };

  config = {
    # Propagate the legacy `allowAliases` option into `aliases.nixpkgs`.
    aliases.nixpkgs = lib.mkDefault config.allowAliases;

    # Collect the assertions from the problems.matchers.* submodules and
    # propagate them into the top-level `assertions` list.
    assertions = lib.concatMap (matcher: matcher.assertions) config.problems.matchers;

    # A plain value rather than `mkDefault`, so that it merges with any
    # user-supplied matchers instead of being overridden by them.
    problems.matchers = [
      {
        kind = "broken";
        handler = "error";
      }
      # Be loud and clear about package removals
      {
        kind = "removal";
        handler = "warn";
      }
    ];
  };
}

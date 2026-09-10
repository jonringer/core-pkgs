/*
  The entry point of this package set, and the one impure file in it. It:

    1. Elaborates `localSystem` and `crossSystem` with defaults as needed.

    2. Evaluates `config`, allowing it to depend on the final package set

    3. Defaults to no non-standard config and no cross-compilation target

    4. Uses the above to infer the default standard environment's (stdenv)
       stages if none are provided

    5. Folds the stages to yield the final fully booted package set for the
       chosen stdenv

  `builtins.currentSystem` below is the only impurity here: everything else
  is derived from the arguments. Pass `localSystem` (or the legacy `system`)
  to evaluate for a platform other than the one Nix is running on.

  TODO: port minfeatures
*/

{
  # The platform packages are built on -- the "build" platform, in GNU
  # Autotools parlance. See `lib.systems` for the division of labour between
  # these two `*System`s and the three `*Platform`s they elaborate into.
  # Passing it wins over `system`, which is only consulted for the default.
  localSystem ? { inherit system; },

  # The legacy spelling of `localSystem`, carrying a bare system double
  # rather than an attribute set. It stays a named argument because nix's
  # auto-call only fills formals a function declares, so an argument reachable
  # any other way could not be set with `--argstr`.
  system ? builtins.currentSystem,

  # The platform packages will ultimately run on -- the "host" platform.
  # Defaults to `localSystem` rather than to `null`, so a native build is the
  # two being equal rather than the cross target being absent. Note that an
  # explicit `crossSystem = null` is not currently accepted.
  crossSystem ? localSystem,

  # Configuration for the package set, as either an attribute set or a
  # function of the final packages. Evaluated through `config/` as a module.
  config ? { },

  # Set to false to make `lib.fileset` abort on use, which the package set
  # forbids internally until <https://github.com/NixOS/nix/issues/11503> is
  # fixed.
  # TODO: remove once that bug is fixed upstream
  __allowFileset ? true,

  # Extra modules folded into the `config` evaluation alongside `config/`.
  # TODO: document this
  modules ? [ ],

  # Overlays extending the package set. Each is a function of the final and
  # previous package sets, and they take part in its fixed point.
  overlays ? [ ],

  # Overlays applied only to the packages built for the host platform, not to
  # the native ones used to build them.
  crossOverlays ? [ ],
}@args:

let
  inputs = { inherit localSystem crossSystem config; };
in
let
  # A function returning the list of bootstrapping stages to fold into the
  # final package set. `stages` below shows the arguments it is given.
  stdenvStages = import ./stdenv;
  pristineLib = import ./lib.nix;
  lib =
    if __allowFileset then
      pristineLib
    else
      pristineLib.extend (
        _: _: {
          fileset = abort ''

            The use of `lib.fileset` is currently forbidden in Nixpkgs due to the
            upstream Nix bug <https://github.com/NixOS/nix/issues/11503>. This
            causes difficult‐to‐debug errors when combined with chroot stores,
            such as in the NixOS installer.

            For packages that require source to be vendored inside Nixpkgs,
            please use a subdirectory of the package instead.
          '';
        }
      );

  inherit (lib) throwIfNot;

  checked =
    (throwIfNot (lib.isList overlays) "The overlays argument to nixpkgs must be a list.")
      (throwIfNot (lib.all lib.isFunction overlays) "All overlays passed to nixpkgs must be functions.")
      (throwIfNot (lib.isList crossOverlays) "The crossOverlays argument to nixpkgs must be a list.")
      (
        throwIfNot (lib.all lib.isFunction crossOverlays) "All crossOverlays passed to nixpkgs must be functions."
      );

  elaboratedLocalSystem = lib.systems.elaborate inputs.localSystem;

  # A native build must come out as `elaboratedLocalSystem` itself, not an
  # equal copy: the sharing is what later makes `hostPlatform == buildPlatform`
  # cheap, and `lib.systems.equals` documents why that matters.
  #
  # Two systems cannot be compared as passed, only once elaborated -- given
  #
  #   localSystem = { system = "x86_64-linux"; };
  #   crossSystem = { config = "x86_64-unknown-linux-gnu"; };
  #
  # both name the same platform, since the vendor and ABI are inferred from the
  # system double. Equal *arguments* do imply equal systems, though, so that
  # case short-circuits and skips the second elaboration.
  elaboratedCrossSystem =
    if inputs.crossSystem == inputs.localSystem then
      elaboratedLocalSystem
    else
      let
        elaboratedCrossSystem = lib.systems.elaborate inputs.crossSystem;
      in
      if lib.systems.equals elaboratedCrossSystem elaboratedLocalSystem then
        elaboratedLocalSystem
      else
        elaboratedCrossSystem;

  configEval = lib.evalModules {
    class = "nixpkgsConfig";
    modules = [
      ./config/build-options.nix
      ./config/package-options.nix
      ./config/overlays.nix
      {
        _file = "nixpkgs.config";
        # Allow both:
        # { /* the config */ } and
        # { pkgs, ... } : { /* the config */ }
        config =
          if lib.isFunction inputs.config then inputs.config { inherit lib pkgs; } else inputs.config;
      }
    ]
    ++ modules;
  };

  config =
    lib.asserts.checkAssertWarn configEval.config.assertions configEval.config.warnings
      configEval.config
    // {
      # Injected lazily for toDevShell passthru — only forced when a user
      # actually calls drv.toDevShell, at which point pkgs is fully resolved.
      mkDevShell = pkgs.mkDevShell;
    };

  # A few packages make a new package set to draw their dependencies from.
  # (Currently to get a cross tool chain, or forced-i686 package.) Rather than
  # give `top-level.nix` all the arguments to this function, even ones that
  # don't concern it, we give it this function to "re-call" nixpkgs, inheriting
  # whatever arguments it doesn't explicitly provide. This way,
  # `top-level.nix` doesn't know more than it needs too.
  #
  # It's OK that `args` doesn't include default arguments from this file:
  # they'll be deterministically inferred. In fact we must *not* include them,
  # because it's important that if some parameter which affects the default is
  # substituted with a different argument, the default is re-inferred.
  #
  # To put this in concrete terms, this function is basically just used today to
  # use package for a different platform for the current platform (namely cross
  # compiling toolchains and 32-bit packages on x86_64). In both those cases we
  # want the provided non-native `localSystem` argument to affect the stdenv
  # chosen.
  #
  # NB!!! This takes its `config` from `args`, i.e. the argument as the caller
  # wrote it -- the same thing `inputs.config` holds, not the `config` bound
  # above. That distinction has to survive every re-entry, because the
  # `evalModules` step turning the one into the other is not idempotent. In
  # other words, if you add `config` to `newArgs`, expect strange very hard to
  # debug errors! (Yes, I'm speaking from experience here.)
  nixpkgsFun = newArgs: import ./. (args // newArgs);

  # Partially apply some arguments for building bootstrapping stage pkgs
  # sets. Only apply arguments which no stdenv would want to override.
  allPackages =
    newArgs:
    import ./stdenv/stage.nix (
      {
        inherit lib nixpkgsFun;
      }
      // newArgs
    );

  boot = import ./stdenv/booter.nix { inherit lib allPackages; };

  stages = stdenvStages {
    inherit
      lib
      config
      overlays
      crossOverlays
      ;
    localSystem = elaboratedLocalSystem;
    crossSystem = elaboratedCrossSystem;
  };

  pkgs = boot stages;

in
checked pkgs

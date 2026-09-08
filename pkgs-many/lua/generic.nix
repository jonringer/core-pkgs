{
  version,
  hash ? null,
  compat ? false,
  isLuaJIT ? false,
  patches ? [ ],
  darwinPatch ? null,
  luajitVariant ? null,
  packageOlder,
  packageAtLeast,
  mkVariantPassthru,
  ...
}@variantArgs:

{
  lib,
  callPackage,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  makeBinaryWrapper,
  packageOverrides ? (final: prev: { }),
  pkgsBuildBuild,
  pkgsBuildHost,
  pkgsBuildTarget,
  pkgsHostHost,
  pkgsTargetTarget,
  pkgs, # Need global pkgs for overrides.nix
  config, # For config.overlays.lua
  ...
}@packageArgs:

let
  # Common passthru for all lua interpreters (from original default.nix)
  passthruFun =
    {
      executable,
      luaversion,
      packageOverrides,
      luaOnBuildForBuild,
      luaOnBuildForHost,
      luaOnBuildForTarget,
      luaOnHostForHost,
      luaOnTargetForTarget,
      luaAttr ? null,
      self, # is luaOnHostForTarget
    }:
    let
      luaPackages =
        callPackage
          (
            {
              lua,
              overrides,
              callPackage,
              makeScopeWithSplicing',
            }:
            let
              # Use the packages.nix directly (lua-packages.nix is at ./packages.nix)
              luaPackagesFun = callPackage ./packages.nix { lua = self; };

              generatedPackages =
                if (builtins.pathExists ./modules/generated-packages.nix) then
                  (
                    final: prev:
                    callPackage ./modules/generated-packages.nix { inherit (final) callPackage; } final prev
                  )
                else
                  (final: prev: { });
              overriddenPackages =
                if builtins.pathExists ./modules/overrides.nix then
                  callPackage ./modules/overrides.nix { }
                else
                  (final: prev: { });

              otherSplices = {
                selfBuildBuild = luaOnBuildForBuild.pkgs or { };
                selfBuildHost = luaOnBuildForHost.pkgs or { };
                selfBuildTarget = luaOnBuildForTarget.pkgs or { };
                selfHostHost = luaOnHostForHost.pkgs or { };
                selfTargetTarget = luaOnTargetForTarget.pkgs or { };
              };

              extensions = lib.composeManyExtensions (
                [
                  generatedPackages
                  overriddenPackages
                ]
                ++ config.overlays.lua
                ++ [
                  overrides
                ]
              );
            in
            makeScopeWithSplicing' {
              inherit otherSplices;
              f = lib.extends extensions luaPackagesFun;
            }
          )
          {
            overrides = packageOverrides;
            lua = self;
          };
    in
    rec {
      buildEnv = callPackage ./wrapper.nix {
        lua = self;
        makeWrapper = makeBinaryWrapper;
        inherit (luaPackages) requiredLuaModules;
      };
      withPackages = import ./with-packages.nix { inherit buildEnv luaPackages; };
      pkgs = luaPackages;
      interpreter = "${self}/bin/${executable}";
      inherit executable luaversion;
      luaOnBuild = luaOnBuildForHost.override {
        inherit packageOverrides;
        self = luaOnBuild;
      };

      tests = callPackage ./tests {
        lua = self;
        inherit (luaPackages) wrapLua;
      };

      inherit luaAttr;
    };

  # Build the Lua interpreter
  luaInterpreter =
    if isLuaJIT then
      # Build LuaJIT variant
      (
        if luajitVariant == "2.0" then
          import ./luajit/2.0.nix {
            inherit
              callPackage
              fetchFromGitHub
              lib
              passthruFun
              ;
            self = luaInterpreter;
          }
        else if luajitVariant == "2.1" then
          import ./luajit/2.1.nix {
            inherit callPackage fetchFromGitHub passthruFun;
            self = luaInterpreter;
          }
        else if luajitVariant == "openresty" then
          import ./luajit/openresty.nix {
            inherit callPackage fetchFromGitHub passthruFun;
            self = luaInterpreter;
          }
        else
          throw "Unknown LuaJIT variant: ${luajitVariant}"
      )
    else
      # Build standard Lua
      callPackage ./interpreter.nix {
        inherit
          version
          hash
          compat
          passthruFun
          ;
        self = luaInterpreter;
        makeWrapper = makeBinaryWrapper;
        patches =
          patches ++ (lib.optional (darwinPatch != null && stdenv.hostPlatform.isDarwin) darwinPatch);
      };

in
# Return the Lua interpreter with mkVariantPassthru added
luaInterpreter.overrideAttrs (oldAttrs: {
  passthru =
    (oldAttrs.passthru or { })
    // mkVariantPassthru variantArgs
    // {
      inherit variantArgs;
      ekapkgs-update.semver-strategy = "patch";
    };
})

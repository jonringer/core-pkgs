# Minimal stdenv

This folder is meant to encapsulate all the logic around stdenv, spliced packages,
and construction of a package set given additional overlays.

The desire is for this to be the base on which larger nix package sets build upon.

## Changes from upstream Nixpkgs

- `stdenv.isCross` is now defined
- `strictDeps` is true by default
- `__structuredAttrs` is true by default
- `enableParallelBuilding` is true by default
- `enableParallelChecking` is true by default
- `enableParallelInstalling` is true by default

## Status

Stdenv's supported:

- [x] x86_64-linux
- [x] aarch64-linux
- [x] aarch64-darwin

## Testing

`default.nix` is meant to be treated in a similar fashion to nixpkgs so, `nix-build`
and `nix repl` workflows should translate to this repo as well:

```
nix-build -A stdenv
/nix/store/lk2ax3a6mqrm5ddkg3s4f31m33w89k85-stdenv-linux
```

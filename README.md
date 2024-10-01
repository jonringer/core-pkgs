# Core-pkgs (WIP)

This repository is meant to be the provider of most common
development concerns for a nixpkgs fork. There should
be a high degree of scrutiny and quality put into the nix
expressions in this repository, as it will impact the most
use cases.

## Structure

```
build-support # Fetchers, shell hooks, and nix utilities
os-specific   # For packages which are platform-specific
pkgs/         # Subdirectories are automatically imported to pkgs
python/       # Python related packaging
  pkgs/       # Directory for python package set, automatically imported
perl/         # Perl related packaging (interpreter) and packages
top-level.nix # Overlay for specifying overrides at `pkgs` scope
default.nix   # Entry point for people to import
```

## Binary cache

*WARNING*: This is a personal server, and should be considered untrusted

```
substituters = https://cache.jonringer.us
trusted-public-keys = cache.jonringer.us:BZogIwFAp94LYcmaOi6xkHGJeRhMcQtFO8l6AmJNsng=
```

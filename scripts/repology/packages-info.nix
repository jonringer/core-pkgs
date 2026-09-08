# Generates a JSON package entry compatible with Repology's NixJsonParser.
#
# Evaluates a single package by attribute name and returns its metadata.
# Used by generate.sh which calls this once per package and merges results.
#
# Usage:
#   nix-instantiate --eval --strict --json \
#     --arg system '"x86_64-linux"' \
#     --arg attrName '"coreutils"' \
#     scripts/repology/packages-info.nix
#
# Returns: { "pname": "...", "version": "...", "meta": { ... } }
# or null if the package cannot be evaluated.

{
  system ? builtins.currentSystem,
  attrName,
}:

let
  pkgs = import ../../.. { inherit system; };
  inherit (pkgs) lib;

  # Attempt to serialize a license value into the format Repology expects.
  serializeLicense =
    l:
    if builtins.isAttrs l && l ? spdxId then
      {
        inherit (l) spdxId;
        fullName = l.fullName or l.shortName or l.spdxId;
      }
      // lib.optionalAttrs (l ? free) { inherit (l) free; }
      // lib.optionalAttrs (l ? url) { inherit (l) url; }
    else if builtins.isAttrs l && l ? fullName then
      {
        inherit (l) fullName;
      }
      // lib.optionalAttrs (l ? free) { inherit (l) free; }
      // lib.optionalAttrs (l ? shortName) { inherit (l) shortName; }
      // lib.optionalAttrs (l ? url) { inherit (l) url; }
    else if builtins.isString l then
      { fullName = l; }
    else
      null;

  serializeLicenses =
    l:
    if builtins.isList l then
      builtins.filter (x: x != null) (map serializeLicense l)
    else
      let
        result = serializeLicense l;
      in
      if result != null then [ result ] else [ ];

  # Extract the relevant meta fields from a derivation.
  extractMeta =
    drv:
    let
      meta = drv.meta or { };
      optionalMetaString =
        key:
        if meta ? ${key} && builtins.isString meta.${key} then
          { ${key} = meta.${key}; }
        else if meta ? ${key} && builtins.isList meta.${key} then
          { ${key} = builtins.head meta.${key}; }
        else
          { };
    in
    { }
    // optionalMetaString "description"
    // optionalMetaString "homepage"
    // optionalMetaString "changelog"
    // optionalMetaString "downloadPage"
    // (if meta ? license then { license = serializeLicenses meta.license; } else { })
    // (if meta ? broken then { inherit (meta) broken; } else { })
    // (if meta ? unfree then { inherit (meta) unfree; } else { })
    // (if meta ? insecure then { inherit (meta) insecure; } else { });

  drv = pkgs.${attrName};

in
if lib.isDerivation drv && drv ? pname && drv ? version then
  {
    pname = drv.pname;
    version = drv.version;
    meta = extractMeta drv;
  }
else
  null

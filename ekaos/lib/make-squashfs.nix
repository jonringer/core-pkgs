# Squashfs image builder for ekaos
#
# Creates a squashfs image containing the closure of the given store paths.
# Used by the ISO image builder to package the nix store.
#
# Usage:
#   import ./make-squashfs.nix {
#     inherit pkgs lib;
#     storeContents = [ config.system.build.toplevel ];
#   }
#
{
  pkgs,
  lib,

  # Store paths whose closures will be included in the squashfs image.
  storeContents ? [ ],

  # Compression settings. Set to null to disable compression.
  # Examples: "zstd -Xcompression-level 6", "xz -Xdict-size 100%", "gzip"
  comp ? "zstd -Xcompression-level 6",

  # Squashfs block size in bytes.
  blockSize ? 1048576,

  # Output file name (without directory).
  fileName ? "nix-store.squashfs",
}:

let
  compFlag = if comp == null then "-no-compression" else "-comp ${comp}";

  closureInfo = pkgs.closureInfo { rootPaths = storeContents; };
in

pkgs.stdenvNoCC.mkDerivation {
  name = fileName;

  nativeBuildInputs = [ pkgs.squashfs-tools ];

  # The image is self-contained; drop references to the build closure.
  unsafeDiscardReferences.out = true;

  buildCommand = ''
    # Include a manifest of the closures in a format suitable for
    # nix-store --load-db.
    cp ${closureInfo}/registration nix-path-registration

    # Generate the squashfs image.
    mksquashfs \
      nix-path-registration \
      $(cat ${closureInfo}/store-paths) \
      $out \
      -no-hardlinks \
      -keep-as-directory \
      -all-root \
      -b ${toString blockSize} \
      ${compFlag} \
      -processors $NIX_BUILD_CORES \
      -root-mode 0755
  '';
}

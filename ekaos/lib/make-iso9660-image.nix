# ISO 9660 image builder for ekaos
#
# Creates a UEFI-bootable ISO 9660 image using xorriso.
# The nix store is packaged as a squashfs image embedded in the ISO.
#
# Usage:
#   import ./make-iso9660-image.nix {
#     inherit pkgs lib;
#     isoName = "ekaos.iso";
#     volumeID = "EKAOS";
#     contents = [ { source = ./readme.txt; target = "/README"; } ];
#     squashfsContents = [ config.system.build.toplevel ];
#   }
#
{
  pkgs,
  lib,

  # The file name of the resulting ISO image.
  isoName ? "ekaos.iso",

  # ISO 9660 volume identifier (max 32 characters).
  volumeID ? "EKAOS",

  # Files and directories to place in the ISO filesystem.
  # List of { source, target } where source is a file/directory and
  # target is the path on the ISO.
  contents ? [ ],

  # Store paths whose closures are compressed as squashfs and placed
  # on the ISO as /nix-store.squashfs.
  squashfsContents ? [ ],

  # Compression settings for the squashfs nix store.
  squashfsCompression ? "zstd -Xcompression-level 6",

  # Path to the EFI boot image (FAT filesystem containing the bootloader).
  # Required for UEFI boot.
  efiBootImage ? null,

  # Whether to compress the resulting ISO with zstd.
  compressImage ? false,
}:

let
  makeSquashfs = import ./make-squashfs.nix {
    inherit pkgs lib;
    storeContents = squashfsContents;
    comp = squashfsCompression;
  };

  needSquashfs = squashfsContents != [ ];
in

assert efiBootImage != null;
assert lib.stringLength volumeID <= 32;

pkgs.stdenvNoCC.mkDerivation {
  name = isoName;

  nativeBuildInputs = [
    pkgs.libisoburn # provides xorriso
  ]
  ++ lib.optional compressImage pkgs.zstd;

  # The image is self-contained; drop references to the build closure.
  unsafeDiscardReferences.out = true;

  buildCommand = ''
    # Create staging directory for ISO contents
    isoDir=$(mktemp -d)

    # Add individual files and directories
    ${lib.concatMapStringsSep "\n" (
      { source, target }:
      ''
        mkdir -p "$isoDir/$(dirname "${target}")"
        cp -a "${source}" "$isoDir/${target}"
      ''
    ) contents}

    # Add squashfs nix store image
    ${lib.optionalString needSquashfs ''
      cp ${makeSquashfs} "$isoDir/nix-store.squashfs"
    ''}

    mkdir -p $out/iso

    # Build the ISO with xorriso
    xorriso \
      -as mkisofs \
      -iso-level 3 \
      -R -J \
      -volid "${volumeID}" \
      -appid ekaos \
      -publisher ekaos \
      -full-iso9660-filenames \
      -joliet-long \
      -eltorito-alt-boot \
      -e EFI/efiboot.img \
      -no-emul-boot \
      -isohybrid-gpt-basdat \
      -o "$out/iso/${isoName}" \
      "$isoDir"

    ${lib.optionalString compressImage ''
      echo "Compressing image..."
      zstd -T$NIX_BUILD_CORES --rm "$out/iso/${isoName}"
    ''}

    # Hydra build product metadata
    mkdir -p $out/nix-support
    echo "${pkgs.stdenv.hostPlatform.system}" > $out/nix-support/system
    ${
      if compressImage then
        ''
          echo "file iso $out/iso/${isoName}.zst" >> $out/nix-support/hydra-build-products
        ''
      else
        ''
          echo "file iso $out/iso/${isoName}" >> $out/nix-support/hydra-build-products
        ''
    }
  '';
}

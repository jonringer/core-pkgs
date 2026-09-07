{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  dav1d,
  rav1e,
  libde265,
  x265,
  libpng,
  libjpeg,
  libaom,
  gdk-pixbuf,

  # for passthru.tests
  imagemagick,
  imv,
  python3Packages,
  vips,
}:

stdenv.mkDerivation rec {
  pname = "libheif";
  version = "1.23.4";

  outputs = [
    "bin"
    "out"
    "dev"
    "man"
    "lib"
  ];

  src = fetchFromGitHub {
    owner = "strukturag";
    repo = "libheif";
    rev = "v${version}";
    hash = "sha256-bxN3YB/nKjrsHa/dM3sTAnWR+wOHk5a6ku6NF+8moQ0=";
  };

  nativeBuildInputs = [
    pkg-config
    cmake
    cmake.configurePhaseHook
  ];

  buildInputs = [
    dav1d
    rav1e
    libde265
    x265
    libpng
    libjpeg
    libaom
    gdk-pixbuf
  ];

  # Fix installation path for gdk-pixbuf module
  PKG_CONFIG_GDK_PIXBUF_2_0_GDK_PIXBUF_MODULEDIR = "${placeholder "lib"}/${gdk-pixbuf.moduleDir}";

  postInstall = ''
    substituteInPlace $out/share/thumbnailers/heif.thumbnailer \
      --replace-fail "TryExec=heif-thumbnailer" "TryExec=$bin/bin/heif-thumbnailer" \
      --replace-fail "Exec=heif-thumbnailer" "Exec=$bin/bin/heif-thumbnailer"
  '';

  # Wrong include path in .cmake.  It's a bit difficult to patch because of special characters.
  postFixup = ''
    sed '/^  INTERFACE_INCLUDE_DIRECTORIES/s|"[^"]*/include"|"${placeholder "dev"}/include"|' \
      -i "$dev"/lib/cmake/libheif/libheif-config.cmake
  '';

  passthru.tests = {
    inherit
      imagemagick
      imv
      vips
      ;
    inherit (python3Packages) pillow-heif;
  };

  meta = {
    homepage = "http://www.libheif.org/";
    description = "ISO/IEC 23008-12:2017 HEIF image file format decoder and encoder";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.unix;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "strukturag" version;
  };
}

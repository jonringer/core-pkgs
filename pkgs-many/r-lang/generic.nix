{
  version,
  src-hash,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  perl,
  gfortran,
  bzip2,
  xz,
  zlib,
  pcre2,
  curl,
  readline,
  cairo,
  libtiff,
  libjpeg,
  libpng,
  pango,
  icu,
  pkg-config,
  which,
  tzdata,
  libx11,
  libxt,
  callPackage,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "r";
  inherit version;

  src = fetchurl {
    url = "https://cran.r-project.org/src/base/R-${lib.versions.major version}/R-${version}.tar.gz";
    hash = src-hash;
  };

  nativeBuildInputs = [
    perl
    pkg-config
    which
    gfortran
  ];

  buildInputs = [
    bzip2
    xz
    zlib
    pcre2
    curl
    readline
    cairo
    libtiff
    libjpeg
    libpng
    pango
    icu
    tzdata
    libx11
    libxt
  ];

  configureFlags = [
    "--enable-R-shlib"
    "--enable-memory-profiling"
    "--with-blas"
    "--with-lapack"
    "--with-readline"
    "--with-cairo"
    "--with-libpng"
    "--with-jpeglib"
    "--with-libtiff"
  ];

  TZDIR = "${tzdata}/share/zoneinfo";

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
    majorVersion = lib.versions.major version;
    minorVersion = lib.versions.majorMinor version;
    buildRPackage = callPackage ./build-r-package.nix {
      r-lang = finalAttrs.finalPackage;
    };
  };

  meta = {
    description = "Free software environment for statistical computing and graphics";
    homepage = "https://www.r-project.org/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix ++ lib.platforms.darwin;
    mainProgram = "R";
    identifiers.cpeParts = {
      vendor = "r-project";
      product = "r";
    };
  };
})

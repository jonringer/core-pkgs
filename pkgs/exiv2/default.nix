{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  gettext,
  removeReferencesTo,
  libiconv,
  brotli,
  expat,
  inih,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "exiv2";
  version = "0.28.9";

  outputs = [
    "out"
    "lib"
    "dev"
    "man"
  ];

  src = fetchFromGitHub {
    owner = "exiv2";
    repo = "exiv2";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ESRiiBBckGIhnhSOMmcF/m1PYi2sLGv1xxE0b22nl5M=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
    gettext
    removeReferencesTo
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    libiconv
  ];

  propagatedBuildInputs = [
    brotli
    expat
    inih
    zlib
  ];

  cmakeFlags = [
    "-DEXIV2_ENABLE_NLS=ON"
    "-DEXIV2_BUILD_DOC=OFF"
    "-DEXIV2_ENABLE_BMFF=ON"
  ];

  preFixup = ''
    remove-references-to -t ${stdenv.cc.cc} $lib/lib/*.so.*.*.* $out/bin/exiv2
  '';

  disallowedReferences = [ stdenv.cc.cc ];

  # causes redefinition of _FORTIFY_SOURCE
  hardeningDisable = [ "fortify3" ];

  meta = {
    homepage = "https://exiv2.org";
    description = "Library and command-line utility to manage image metadata";
    mainProgram = "exiv2";
    platforms = lib.platforms.all;
    license = lib.licenses.gpl2Plus;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "exiv2" finalAttrs.version;
  };
})

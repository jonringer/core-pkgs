{
  lib,
  stdenv,
  fetchurl,
  perl,
  texinfo,

  # for passthru.tests
  gnutls,
  samba ? null,
  qemu,
  runUnitTests,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libtasn1";
  version = "4.20.0";

  src = fetchurl {
    url = "mirror://gnu/libtasn1/libtasn1-${finalAttrs.version}.tar.gz";
    sha256 = "sha256-kuDjvUwC1K7udgNrLd2D8McyukzaXLcdWDJysjWHp2w=";
  };

  outputs = [
    "out"
    "dev"
    "devdoc"
  ];
  outputBin = "dev";

  nativeBuildInputs = [
    texinfo
    perl
  ];

  preCheck =
    if stdenv.hostPlatform.isDarwin then "export DYLD_LIBRARY_PATH=`pwd`/lib/.libs" else null;

  passthru.tests = {
    inherit gnutls qemu;
    unittests = runUnitTests finalAttrs.finalPackage;
  }
  // lib.optionalAttrs (samba != null) { inherit samba; };

  meta = {
    homepage = "https://www.gnu.org/software/libtasn1/";
    description = "ASN.1 library";
    longDescription = ''
      Libtasn1 is the ASN.1 library used by GnuTLS, GNU Shishi and some
      other packages.  The goal of this implementation is to be highly
      portable, and only require an ANSI C89 platform.
    '';
    license = lib.licenses.lgpl2Plus;
    platforms = lib.platforms.all;
    changelog = "https://gitlab.com/gnutls/libtasn1/-/blob/v${finalAttrs.version}/NEWS";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "gnu" finalAttrs.version;
  };
})

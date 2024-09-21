{ lib, stdenv
, fetchurl
, autoreconfHook
, docbook_xsl
, docbook_xml_dtd_43
, gtk-doc ? null
, lzip
, libidn2
, libunistring
, libxslt
, pkg-config
, python3
, buildPackages
, publicsuffix-list
, withManual ? false
}:

assert withManual -> gtk-doc != null;

stdenv.mkDerivation rec {
  pname = "libpsl";
  version = "0.21.5";

  src = fetchurl {
    url = "https://github.com/rockdaboot/libpsl/releases/download/${version}/libpsl-${version}.tar.lz";
    hash = "sha256-mp9qjG7bplDPnqVUdc0XLdKEhzFoBOnHMgLZdXLNOi0=";
  };

  # bin/psl-make-dafsa brings a large runtime closure through python3
  outputs = lib.optional (!stdenv.hostPlatform.isStatic) "bin" ++ [ "out" "dev" ];

  nativeBuildInputs = [
    autoreconfHook
    lzip
    pkg-config
  ] ++ lib.optionals withManual [
    docbook_xsl
    docbook_xml_dtd_43
    gtk-doc
    libxslt
  ];

  buildInputs = [
    libidn2
    libunistring
    libxslt
  ] ++ lib.optional (!stdenv.hostPlatform.isStatic) python3;

  propagatedBuildInputs = [
    publicsuffix-list
  ];

  postPatch = lib.optionalString (!stdenv.hostPlatform.isStatic) ''
    patchShebangs src/psl-make-dafsa
  '';

  preAutoreconf = lib.optionalString withManual ''
    gtkdocize
  '';

  configureFlags = [
    "--with-psl-distfile=${publicsuffix-list}/share/publicsuffix/public_suffix_list.dat"
    "--with-psl-file=${publicsuffix-list}/share/publicsuffix/public_suffix_list.dat"
    "--with-psl-testfile=${publicsuffix-list}/share/publicsuffix/test_psl.txt"
    "PYTHON=${lib.getExe buildPackages.python3}"
  ] ++ lib.optionals withManual [
    "--enable-gtk-doc"
    "--enable-man"
  ];

  enableParallelBuilding = true;

  doCheck = true;

  meta = with lib; {
    description = "C library for the Publix Suffix List";
    longDescription = ''
      libpsl is a C library for the Publix Suffix List (PSL). A "public suffix"
      is a domain name under which Internet users can directly register own
      names. Browsers and other web clients can use it to avoid privacy-leaking
      "supercookies" and "super domain" certificates, for highlighting parts of
      the domain in a user interface or sorting domain lists by site.
    '';
    homepage = "https://rockdaboot.github.io/libpsl/";
    changelog = "https://raw.githubusercontent.com/rockdaboot/${pname}/${pname}-${version}/NEWS";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "psl";
    platforms = platforms.unix ++ platforms.windows;
    pkgConfigModules = [ "libpsl" ];
  };
}

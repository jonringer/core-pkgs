{
  version,
  hash,
  isMinimalBuild ? false,
  buildDocs ? !isMinimalBuild,
  mkVariantPassthru,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  fetchurl,
  autoreconfHook,
  docbook-xsl-nons,
  docbook-xml-dtd,
  gtk-doc,
  lzip,
  libidn2,
  libunistring,
  libxslt,
  pkg-config,
  buildPackages,
  publicsuffix-list,
  runUnitTests,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libpsl" + lib.optionalString isMinimalBuild "-minimal";
  inherit version;

  src = fetchurl {
    url = "https://github.com/rockdaboot/libpsl/releases/download/${version}/libpsl-${version}.tar.lz";
    inherit hash;
  };

  patches = [ ];

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    autoreconfHook
    lzip
    pkg-config
  ]
  ++ lib.optionals buildDocs [
    docbook-xsl-nons
    docbook-xml-dtd.v4_3
    gtk-doc
    libxslt
  ];

  buildInputs = [
    libidn2
    libunistring
  ]
  ++ lib.optionals buildDocs [
    libxslt
  ];

  propagatedBuildInputs = [
    publicsuffix-list
  ];

  # When not building docs:
  #  - Remove m4/gtk-doc.m4 so that `m4_ifdef([GTK_DOC_CHECK], ...)` in
  #    configure.ac takes the false branch, preventing autoreconf from
  #    invoking `gtkdocize` (which would not be available).
  #  - Replace docs/libpsl/Makefile.am with an empty stub. The original
  #    references gtk-doc.make and assumes variables only defined by
  #    GTK_DOC_CHECK; since the top-level Makefile.am only descends into
  #    docs/libpsl when ENABLE_GTK_DOC or ENABLE_MAN is true (and both are
  #    off in the minimal build), a no-op Makefile.am is sufficient to
  #    satisfy AC_CONFIG_FILES([docs/libpsl/Makefile ...]).
  postPatch = lib.optionalString (!buildDocs) ''
    rm -f m4/gtk-doc.m4
    : > docs/libpsl/Makefile.am
  '';

  # bin/psl-make-dafsa brings a large runtime closure through python3
  # use the libpsl-with-scripts package if you need this
  postInstall = ''
    rm -f $out/bin/psl-make-dafsa $out/share/man/man1/psl-make-dafsa*
  '';

  preAutoreconf = lib.optionalString buildDocs ''
    gtkdocize
  '';

  configureFlags = [
    "--with-psl-distfile=${publicsuffix-list}/share/publicsuffix/public_suffix_list.dat"
    "--with-psl-file=${publicsuffix-list}/share/publicsuffix/public_suffix_list.dat"
    "--with-psl-testfile=${publicsuffix-list}/share/publicsuffix/test_psl.txt"
    "PYTHON=${lib.getExe buildPackages.python3}"
  ]
  ++ lib.optionals buildDocs [
    "--enable-man"
  ]
  ++ lib.optionals (!buildDocs) [
    "--disable-man"
    # Note: gtk-doc-related flags (--enable-gtk-doc, --enable-gtk-doc-html,
    # --enable-gtk-doc-pdf) are only defined by the GTK_DOC_CHECK macro. We
    # remove m4/gtk-doc.m4 in postPatch (see above), so those options are
    # absent from configure and passing --disable-gtk-doc would be rejected
    # as an unrecognized option.
  ];

  passthru = mkVariantPassthru variantArgs // {
    ekapkgs-update.semver-strategy = "patch";
    tests = {
      unittests = runUnitTests finalAttrs.finalPackage;
    };
  };

  meta = {
    description = "C library for the Publix Suffix List";
    longDescription = ''
      libpsl is a C library for the Publix Suffix List (PSL). A "public suffix"
      is a domain name under which Internet users can directly register own
      names. Browsers and other web clients can use it to avoid privacy-leaking
      "supercookies" and "super domain" certificates, for highlighting parts of
      the domain in a user interface or sorting domain lists by site.
    '';
    homepage = "https://rockdaboot.github.io/libpsl/";
    changelog = "https://raw.githubusercontent.com/rockdaboot/libpsl/libpsl-${version}/NEWS";
    license = lib.licenses.mit;
    mainProgram = "psl";
    platforms = lib.platforms.unix ++ lib.platforms.windows;
    pkgConfigModules = [ "libpsl" ];
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "rockdaboot" finalAttrs.version;
  };
})

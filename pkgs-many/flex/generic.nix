{
  version,
  src-hash,
  packageOlder,
  packageAtLeast,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  gcc13Stdenv,
  buildPackages,
  fetchurl,
  bison,
  m4,
  autoreconfHook,
  help2man,
  flex ? null,
  texinfo ? null,
  # for passthru.tests
  elfutils,
  libpcap,
  iproute2,
}:

# Avoid 'fetchpatch' to allow 'flex' to be used as a possible 'gcc'
# dependency during bootstrap. Useful when gcc is built from snapshot
# or from a git tree (flex lexers are not pre-generated there).
let
  is2_5 = packageOlder "2.6";
  stdenv' = if is2_5 then gcc13Stdenv else stdenv;
  url =
    if is2_5 then
      "https://github.com/westes/flex/releases/download/flex-${version}/flex-${version}.tar.gz"
    else
      "https://github.com/westes/flex/releases/download/v${version}/flex-${version}.tar.gz";

  needsTexinfo = is2_5;
in
stdenv'.mkDerivation rec {
  pname = "flex";
  inherit version;

  # Use the published sources associated with a tag to avoid the need to run flex as part of build
  src = fetchurl {
    inherit url;
    hash = src-hash;
  };

  patches = lib.optionals (packageAtLeast "2.6") [
    (fetchurl {
      url = "https://raw.githubusercontent.com/lede-project/source/0fb14a2b1ab2f82ce63f4437b062229d73d90516/tools/flex/patches/200-build-AC_USE_SYSTEM_EXTENSIONS-in-configure.ac.patch";
      hash = "sha256-eSDA0hIIfQbXx0DP1dTQU2uIqBxIXjbB6O+E134g91Y=";
    })
  ];

  postPatch = ''
    patchShebangs tests
  ''
  + lib.optionalString (stdenv.buildPlatform != stdenv.hostPlatform) ''
    substituteInPlace Makefile.in --replace "tests" " "

    substituteInPlace doc/Makefile.am --replace 'flex.1: $(top_srcdir)/configure.ac' 'flex.1: '
  '';

  depsBuildBuild = lib.optionals (packageAtLeast "2.6") [ buildPackages.stdenv.cc ];

  nativeBuildInputs = [
    bison
    help2man
    autoreconfHook
  ]
  # v2.5.35 needs texinfo
  ++ lib.optionals needsTexinfo [ texinfo ];

  buildInputs = lib.optionals (packageAtLeast "2.6") [ bison ];

  propagatedBuildInputs = [ m4 ];

  preConfigure = lib.optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
  '';

  postConfigure = lib.optionalString (stdenv.hostPlatform.isDarwin || stdenv.hostPlatform.isCygwin) ''
    sed -i Makefile -e 's/-no-undefined//;'
  '';

  dontDisableStatic = stdenv.buildPlatform != stdenv.hostPlatform;

  doCheck = false;

  postInstall = ''
    ln -s $out/bin/flex $out/bin/lex
  '';

  passthru.tests = {
    inherit elfutils libpcap iproute2;
  };
  passthru.ekapkgs-update.semver-strategy = "patch";

  meta = {
    homepage = "https://github.com/westes/flex";
    description = "Fast lexical analyser generator";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
    mainProgram = "flex";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "westes" version;
  };
}

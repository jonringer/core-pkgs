{
  version,
  src-hash,
  useFetchzip ? false,
  packageOlder,
  packageAtLeast,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  fetchzip,
  fetchpatch,
  pkg-config,
  tcl,
  libxft,
  zip,
  zlib,
  enableAqua ? stdenv.hostPlatform.isDarwin,
}:

let
  release = lib.versions.majorMinor version;

  # Each tk version must pair with its matching tcl version
  matchedTcl =
    if packageAtLeast "9.0" then
      tcl.v9_0
    else if packageAtLeast "8.6" then
      tcl.v8_6
    else
      tcl.v8_5;

  src =
    if useFetchzip then
      fetchzip {
        url = "mirror://sourceforge/tcl/tk${version}-src.tar.gz";
        hash = src-hash;
      }
    else
      fetchurl {
        url = "mirror://sourceforge/tcl/tk${version}-src.tar.gz";
        hash = src-hash;
      };

  patches =
    lib.optionals (packageAtLeast "8.6") [
      ./tk-8_6_13-find-library.patch
    ]
    ++ lib.optionals (packageOlder "8.6" && stdenv.hostPlatform.isDarwin) [
      (fetchpatch {
        name = "module_scope.patch";
        url = "https://core.tcl-lang.org/tk/vpatch?from=ef6c6960c53ea30c&to=9b8aa74eebed509a";
        extraPrefix = "";
        sha256 = "0crhf4zrzdpc1jdgyv6l6mxqgmny12r3i39y1i0j8q3pbqkd04bv";
      })
    ];

in
matchedTcl.mkTclDerivation {
  pname = "tk";
  version = matchedTcl.version;

  inherit src patches;

  outputs = [
    "out"
    "man"
    "dev"
  ];

  setOutputFlags = false;

  preConfigure = ''
    configureFlagsArray+=(--mandir=$man/share/man --enable-man-symlinks)
    cd unix
  '';

  postPatch = ''
    for file in $(find library/demos/. -type f ! -name "*.*"); do
      substituteInPlace $file --replace "exec wish" "exec $out/bin/wish"
    done
  '';

  postInstall =
    let
      libtclstring = lib.optionalString (lib.versionAtLeast matchedTcl.version "9.0") "tcl${lib.versions.major matchedTcl.version}";
      libfile = "$out/lib/lib${libtclstring}tk${matchedTcl.release}${stdenv.hostPlatform.extensions.sharedLibrary}";
    in
    ''
      ln -s $out/bin/wish* $out/bin/wish
      cp ../{unix,generic}/*.h $out/include
      ln -s ${libfile} $out/lib/libtk${stdenv.hostPlatform.extensions.sharedLibrary}
    ''
    + lib.optionalString (stdenv.hostPlatform.isDarwin) ''
      cp ../macosx/*.h $out/include
    '';

  configureFlags = [
    "--enable-threads"
  ]
  ++ lib.optional stdenv.hostPlatform.is64bit "--enable-64bit"
  ++ lib.optional enableAqua "--enable-aqua"
  ++ lib.optional (lib.versionAtLeast matchedTcl.version "9.0") "--disable-zipfs";

  nativeBuildInputs = [
    pkg-config
  ]
  ++ lib.optionals (lib.versionAtLeast matchedTcl.version "9.0") [
    zip
  ];
  buildInputs = lib.optionals (lib.versionAtLeast matchedTcl.version "9.0") [
    zlib
  ];

  propagatedBuildInputs = [
    libxft
  ];

  doCheck = false;

  tcl = matchedTcl;

  passthru = rec {
    inherit (matchedTcl) release version;
    libPrefix = "tk${matchedTcl.release}";
    libdir = "lib/${libPrefix}";
  };

  passthru.ekapkgs-update.semver-strategy = "patch";

  meta = {
    description = "Widget toolkit that provides a library of basic elements for building a GUI in many different programming languages";
    homepage = "https://www.tcl.tk/";
    license = lib.licenses.tcltk;
    platforms = lib.platforms.all;
    broken =
      stdenv.hostPlatform.isDarwin && lib.elem (lib.versions.majorMinor matchedTcl.version) [ "8.5" ];
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "tcl" version;
  };
}

{
  version,
  src-hash,
  withXorg ? false,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  fetchFromGitLab,
  autoreconfHook,
  pkg-config,
  cairo,
  expat,
  flex,
  fontconfig,
  gd,
  gts,
  libjpeg,
  libpng,
  libtool,
  makeWrapper,
  pango,
  bash,
  bison,
  xorg,
  python3,

  # for passthru.tests
  exiv2 ? null,
  graphicsmagick ? null,
}:

let
  inherit (lib) optional optionals optionalString;
in
stdenv.mkDerivation rec {
  pname = "graphviz";
  inherit version;

  src = fetchFromGitLab {
    owner = "graphviz";
    repo = "graphviz";
    rev = version;
    hash = src-hash;
  };

  nativeBuildInputs = [
    autoreconfHook
    makeWrapper
    pkg-config
    python3
    bison
    flex
  ];

  buildInputs = [
    libpng
    libjpeg
    expat
    fontconfig
    gd
    gts
    pango
    bash
  ]
  ++ optionals withXorg (with xorg; [ libXrender ]);

  hardeningDisable = [ "fortify" ];

  configureFlags = [
    "--with-ltdl-lib=${libtool.lib}/lib"
    "--with-ltdl-include=${libtool}/include"
  ]
  ++ optional (xorg == null || !withXorg) "--without-x";

  CPPFLAGS = optionalString (withXorg && stdenv.hostPlatform.isDarwin) "-I${cairo.dev}/include/cairo";

  doCheck = false; # fails with "Graphviz test suite requires ksh93" which is not in nixpkgs

  preAutoreconf = ''
    ./autogen.sh
  '';

  postFixup = optionalString withXorg ''
    substituteInPlace $out/bin/vimdot \
      --replace-warn '"/usr/bin/vi"' '"$(command -v vi)"' \
      --replace-warn '"/usr/bin/vim"' '"$(command -v vim)"' \
      --replace-warn /usr/bin/vimdot $out/bin/vimdot

    wrapProgram $out/bin/vimdot --prefix PATH : "$out/bin"
  '';

  passthru.tests = {
    inherit (python3.pkgs)
      graphviz
      pydot
      pygraphviz
      xdot
      ;
  }
  // lib.optionalAttrs (exiv2 != null) { inherit exiv2; }
  // lib.optionalAttrs (graphicsmagick != null) { inherit graphicsmagick; };

  meta = {
    homepage = "https://graphviz.org";
    description = "Graph visualization tools";
    license = lib.licenses.epl10;
    platforms = lib.platforms.unix;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "graphviz" version;
  };
}

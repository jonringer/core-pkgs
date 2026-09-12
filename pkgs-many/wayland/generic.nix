{
  version,
  src-hash,
  patches ? [ ],
  packageAtLeast,
  packageOlder,
  mkVariantPassthru,
  isScanner ? false,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  meson,
  pkg-config,
  ninja,
  withTests ? stdenv.hostPlatform.isLinux,
  libffi,
  epoll-shim ? null,
  graphviz-nox ? null,
  expat,
  libxml2,
  doxygen,
  libxslt,
  xmlto,
  python3,
  docbook-xsl-nons,
  docbook-xml-dtd,
  testers,
  # For referencing scanner from top-level wayland build
  wayland,
}:

let
  # TODO(corepkgs): enable these
  # withDocs = !isScanner;
  # withTests = !isScanner;
  withDocumentation =
    graphviz-nox != null && (!isScanner) && stdenv.hostPlatform == stdenv.buildPlatform;
  withTests = false;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "wayland" + lib.optionalString isScanner "-scanner";
  inherit version;

  src = fetchurl {
    url =
      with finalAttrs;
      "https://gitlab.freedesktop.org/wayland/wayland/-/releases/${version}/downloads/wayland-${version}.tar.xz";
    hash = src-hash;
  };

  inherit patches;

  postPatch = lib.optionalString withDocumentation ''
    patchShebangs doc/doxygen/gen-doxygen.py
  '';

  outputs = [
    "out"
    "dev"
  ]
  ++ lib.optionals withDocumentation [
    "doc"
    "man"
  ];
  separateDebugInfo = true;

  mesonFlags = [
    (lib.mesonBool "documentation" withDocumentation)
    (lib.mesonBool "tests" withTests)
    (lib.mesonBool "scanner" isScanner)
  ];

  depsBuildBuild = [
    pkg-config
  ];

  nativeBuildInputs = [
    meson
    meson.configurePhaseHook
    pkg-config
    ninja
  ]
  ++ lib.optionals (!isScanner) [
    wayland.scanner
  ]
  ++ lib.optionals withDocumentation [
    (graphviz-nox.override { pango = null; }) # To avoid an infinite recursion
    doxygen
    libxslt
    xmlto
    python3
    docbook-xml-dtd.v4_5
    docbook-xsl-nons
  ];

  buildInputs = [
    libffi
  ]
  ++ lib.optionals isScanner [
    expat
    libxml2
  ]
  ++ lib.optionals (!stdenv.hostPlatform.isLinux) (lib.optional (epoll-shim != null) epoll-shim)
  ++ lib.optionals withDocumentation [
    docbook-xsl-nons
    docbook-xml-dtd.v4_5
    docbook-xml-dtd.v4_2
  ];

  passthru =
    mkVariantPassthru {
      tests.pkg-config = testers.hasPkgConfigModules {
        package = finalAttrs.finalPackage;
      };
    }
    // {
      ekapkgs-update.semver-strategy = "patch";
    };

  meta = {
    description = "Core Wayland window system code and protocol";
    longDescription = ''
      Wayland is a project to define a protocol for a compositor to talk to its
      clients as well as a library implementation of the protocol.
      The wayland protocol is essentially only about input handling and buffer
      management, but also handles drag and drop, selections, window management
      and other interactions that must go through the compositor (but not
      rendering).
    '';
    homepage = "https://wayland.freedesktop.org/";
    license = lib.licenses.mit; # Expat version
    platforms = lib.platforms.unix;
    # requires more work: https://gitlab.freedesktop.org/wayland/wayland/-/merge_requests/481
    badPlatforms = lib.platforms.darwin;

    pkgConfigModules = [
      "wayland-client"
      "wayland-cursor"
      "wayland-egl"
      "wayland-egl-backend"
      "wayland-server"
    ];
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "wayland" finalAttrs.version;
  };
})

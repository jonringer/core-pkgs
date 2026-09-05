{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  glib,
  freetype,
  meson,
  ninja,
  python3,
  graphite2,
  withGraphite2 ? true,
  withIcu ? false,
  icu,
  testers,

  # for passthru.tests
  pango,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "harfbuzz";
  version = "14.4.0";

  src = fetchurl {
    url = "https://github.com/harfbuzz/harfbuzz/releases/download/${finalAttrs.version}/harfbuzz-${finalAttrs.version}.tar.xz";
    hash = "sha256-I1ftlmxs7Xv6cgsGQMAjEGWvARWPvqIVCT/6Fa7UQ3E=";
  };

  patches = [ ./disable-check-symbols-test.patch ];

  postPatch = ''
    patchShebangs src/*.py test
  '';

  outputs = [
    "out"
    "dev"
  ];
  outputBin = "dev";

  mesonFlags = [
    (lib.mesonEnable "cairo" false)
    (lib.mesonEnable "raster" false)
    (lib.mesonEnable "chafa" false)
    (lib.mesonEnable "coretext" false)
    (lib.mesonEnable "graphite" withGraphite2)
    (lib.mesonEnable "icu" withIcu)
    (lib.mesonEnable "introspection" false)
    (lib.mesonEnable "docs" false)
    (lib.mesonEnable "gpu" false)
    (lib.mesonEnable "gpu_demo" false)
  ];

  depsBuildBuild = [
    pkg-config
  ];

  nativeBuildInputs = [
    meson
    meson.configurePhaseHook
    ninja
    pkg-config
    python3
    glib
  ];

  buildInputs = [
    glib
    freetype
  ];

  propagatedBuildInputs = lib.optional withGraphite2 graphite2 ++ lib.optional withIcu icu;

  passthru.tests = {
    pkg-config = testers.hasPkgConfigModules {
      package = finalAttrs.finalPackage;
    };
    inherit pango;
  };

  meta = {
    description = "OpenType text shaping engine";
    homepage = "https://harfbuzz.github.io/";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    pkgConfigModules = [
      "harfbuzz"
      "harfbuzz-gobject"
      "harfbuzz-subset"
    ];
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "harfbuzz_project" finalAttrs.version;
  };
})

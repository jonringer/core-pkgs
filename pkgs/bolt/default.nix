{
  stdenv,
  lib,
  meson,
  ninja,
  pkg-config,
  fetchFromGitLab,
  fetchpatch,
  asciidoc,
  libxml2,
  libxslt,
  docbook_xml_dtd_45,
  docbook-xsl-nons,
  glib,
  systemd,
  polkit,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bolt";
  version = "0.9.8";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "bolt";
    repo = "bolt";
    tag = finalAttrs.version;
    hash = "sha256-sDPipSIT2MJMdsOjOQSB+uOe6KXzVnyAqcQxPPr2NsU=";
  };

  patches = [
    # Test does not work on ZFS with atime disabled.
    # Upstream issue: https://gitlab.freedesktop.org/bolt/bolt/-/issues/167
    (fetchpatch {
      url = "https://gitlab.freedesktop.org/bolt/bolt/-/commit/c2f1d5c40ad71b20507e02faa11037b395fac2f8.diff";
      revert = true;
      hash = "sha256-6w7ll65W/CydrWAVi/qgzhrQeDv1PWWShulLxoglF+I=";
    })
  ];

  depsBuildBuild = [
    pkg-config
  ];

  nativeBuildInputs = [
    asciidoc
    docbook_xml_dtd_45
    docbook-xsl-nons
    libxml2
    libxslt
    meson
    meson.configurePhaseHook
    ninja
    pkg-config
    glib
  ];

  buildInputs = [
    polkit
    systemd
  ];

  postPatch = ''
    patchShebangs scripts tests
  '';

  mesonFlags = [
    "-Dlocalstatedir=/var"
  ];

  env = {
    PKG_CONFIG_SYSTEMD_SYSTEMDSYSTEMUNITDIR = "${placeholder "out"}/lib/systemd/system";
    PKG_CONFIG_UDEV_UDEVDIR = "${placeholder "out"}/lib/udev";
  };

  meta = {
    description = "Thunderbolt 3 device management daemon";
    mainProgram = "boltctl";
    homepage = "https://gitlab.freedesktop.org/bolt/bolt";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.linux;
  };
})

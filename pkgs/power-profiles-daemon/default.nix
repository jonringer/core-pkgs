{
  stdenv,
  lib,
  pkg-config,
  meson,
  ninja,
  fetchFromGitLab,
  libgudev,
  glib,
  polkit,
  gobject-introspection,
  gettext,
  gtk-doc,
  docbook-xsl-nons,
  docbook-xml-dtd,
  libxml2,
  libxslt,
  upower,
  systemd,
  python3,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "power-profiles-daemon";
  version = "0.30";

  outputs = [
    "out"
    "devdoc"
  ];

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "upower";
    repo = "power-profiles-daemon";
    rev = finalAttrs.version;
    hash = "sha256-iQUhA46BEln8pyIBxM/MY7An8BzfiFjxZdR/tUIj4S4=";
  };

  nativeBuildInputs = [
    pkg-config
    meson
    meson.configurePhaseHook
    ninja
    gettext
    gtk-doc
    docbook-xsl-nons
    docbook-xml-dtd.v4_1_2
    libxml2
    libxslt
    gobject-introspection
    python3
  ];

  buildInputs = [
    libgudev
    systemd
    upower
    glib
    polkit
  ];

  strictDeps = true;

  mesonFlags = [
    "-Dsystemdsystemunitdir=${placeholder "out"}/lib/systemd/system"
    "-Dgtk_doc=true"
    "-Dpylint=disabled"
    "-Dtests=false"
    "-Dmanpage=disabled"
    "-Dbashcomp=disabled"
    "-Dzshcomp="
  ];

  env.PKG_CONFIG_POLKIT_GOBJECT_1_POLICYDIR = "${placeholder "out"}/share/polkit-1/actions";

  postPatch = ''
    patchShebangs --host \
      src/powerprofilesctl
  '';

  # TODO(corepkgs): Port pygobject3 Python package for full powerprofilesctl support.
  # The CLI tool needs pygobject3 at runtime for GObject introspection bindings.

  meta = {
    homepage = "https://gitlab.freedesktop.org/upower/power-profiles-daemon";
    description = "Makes user-selected power profiles handling available over D-Bus";
    mainProgram = "powerprofilesctl";
    platforms = lib.platforms.linux;
    license = lib.licenses.gpl3Plus;
  };
})

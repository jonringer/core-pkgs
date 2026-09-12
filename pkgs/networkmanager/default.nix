{
  lib,
  stdenv,
  fetchurl,
  replaceVars,
  gettext,
  pkg-config,
  dbus,
  libuuid,
  polkit,
  gnutls,
  ppp,
  dhcpcd,
  iptables,
  nftables,
  python3,
  vala,
  libgcrypt,
  dnsmasq,
  bluez,
  readline,
  libselinux,
  audit,
  gobject-introspection,
  perl,
  modemmanager,
  openresolv,
  libndp,
  newt,
  slang,
  ethtool,
  sed,
  kmod,
  jansson,
  elfutils,
  gtk-doc,
  libxslt,
  docbook-xsl-nons,
  docbook-xml-dtd,
  curl,
  meson,
  mesonEmulatorHook,
  ninja,
  libpsl,
  mobile-broadband-provider-info,
  buildPackages,
  systemd,
  udev,
  udevCheckHook,
  withSystemd ? true,
}:

let
  # TODO(corepkgs): Enable docs when pygobject3 is available in python3.pkgs
  enableDocs = false;
  isNative = stdenv.buildPlatform == stdenv.hostPlatform;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "networkmanager";
  version = "1.58.1";

  src = fetchurl {
    url = "https://gitlab.freedesktop.org/NetworkManager/NetworkManager/-/releases/${finalAttrs.version}/downloads/NetworkManager-${finalAttrs.version}.tar.xz";
    hash = "sha256-Jihkz9GYEj0+Xb6Rk3RBuX7pBZ1tcS4aW/uxxUZo0U0=";
  };

  outputs = [
    "out"
    "dev"
  ]
  ++ lib.optionals enableDocs [
    "devdoc"
    "man"
    "doc"
  ];

  mesonFlags = [
    # System paths
    "--sysconfdir=/etc"
    "--localstatedir=/var"
    (lib.mesonOption "systemdsystemunitdir" (
      if withSystemd then "${placeholder "out"}/etc/systemd/system" else "no"
    ))
    # to enable link-local connections
    "-Dudev_dir=${placeholder "out"}/lib/udev"
    "-Ddbus_conf_dir=${placeholder "out"}/share/dbus-1/system.d"
    "-Dkernel_firmware_dir=/run/current-system/firmware"

    # Platform
    "-Dmodprobe=${kmod}/bin/modprobe"
    (lib.mesonOption "session_tracking" (if withSystemd then "systemd" else "no"))
    (lib.mesonBool "systemd_journal" withSystemd)
    "-Dlibaudit=yes-disabled-by-default"
    "-Dpolkit_agent_helper_1=/run/wrappers/bin/polkit-agent-helper-1"

    # Features
    "-Diwd=true"
    "-Dpppd=${ppp}/bin/pppd"
    "-Diptables=${iptables}/bin/iptables"
    "-Dnft=${nftables}/bin/nft"
    "-Dmodem_manager=true"
    "-Dnmtui=true"
    "-Ddnsmasq=${dnsmasq}/bin/dnsmasq"
    "-Dqt=false"
    "-Dnbft=false"
    "-Dclat=false"

    # Handlers
    "-Dresolvconf=${openresolv}/bin/resolvconf"

    # DHCP clients
    "-Ddhcpcd=${dhcpcd}/bin/dhcpcd"

    # Miscellaneous
    "-Ddocs=${lib.boolToString (enableDocs && isNative)}"
    "-Dman=${lib.boolToString (enableDocs && isNative)}"
    "-Dtests=no"
    "-Dcrypto=gnutls"
    "-Dmobile_broadband_provider_info_database=${mobile-broadband-provider-info}/share/mobile-broadband-provider-info/serviceproviders.xml"
  ];

  patches = [
    (replaceVars ./fix-paths.patch {
      inherit
        ethtool
        sed
        ;
      runtimeShell = "${stdenv.shell}";
    })

    ./fix-install-paths.patch
  ];

  buildInputs = [
    (if withSystemd then systemd else udev)
    libselinux
    audit
    libpsl
    libuuid
    polkit
    ppp
    libndp
    curl
    mobile-broadband-provider-info
    bluez
    dnsmasq
    modemmanager
    readline
    newt
    slang
    jansson
    dbus
  ];

  propagatedBuildInputs = [
    gnutls
    libgcrypt
  ];

  nativeBuildInputs = [
    meson
    meson.configurePhaseHook
    ninja
    gettext
    pkg-config
    vala
    gobject-introspection
    perl
    elfutils
    python3
    udevCheckHook
  ]
  ++ lib.optionals (!stdenv.buildPlatform.canExecute stdenv.hostPlatform) [
    mesonEmulatorHook
  ]
  ++ lib.optionals enableDocs [
    gtk-doc
    libxslt
    docbook-xsl-nons
    docbook-xml-dtd.v4_1_2
    docbook-xml-dtd.v4_2
    docbook-xml-dtd.v4_3
  ];

  postPatch = ''
    patchShebangs ./tools

    substituteInPlace meson.build \
      --replace "'vala', req" "'vala', native: false, req"
  ''
  + lib.optionalString withSystemd ''
    substituteInPlace data/NetworkManager.service.in \
      --replace-fail /usr/bin/busctl ${systemd}/bin/busctl
  '';

  preBuild = lib.optionalString enableDocs ''
    mkdir -p ${placeholder "out"}/lib
    ln -s $PWD/src/libnm-client-impl/libnm.so.0 ${placeholder "out"}/lib/libnm.so.0
  '';

  postFixup = lib.optionalString (!isNative && enableDocs) ''
    cp -r ${buildPackages.networkmanager.devdoc} $devdoc
    cp -r ${buildPackages.networkmanager.man} $man
  '';

  meta = {
    homepage = "https://networkmanager.dev";
    description = "Network configuration and management tool";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "gnome" finalAttrs.version;
  };
})

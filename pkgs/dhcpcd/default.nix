{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  udev,
  runtimeShellPackage,
  runtimeShell,
  withUdev ? stdenv.hostPlatform.isLinux && !stdenv.hostPlatform.isStatic,
  enablePrivSep ? false,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dhcpcd";
  version = "10.5.2";

  src = fetchFromGitHub {
    owner = "NetworkConfiguration";
    repo = "dhcpcd";
    rev = "v${finalAttrs.version}";
    hash = "sha256-lrV6SaB/HmTptZigZ1Lf28eUPz0igxyT6omZwXDSuGM=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    runtimeShellPackage
  ]
  ++ lib.optionals withUdev [ udev ];

  postPatch = ''
    substituteInPlace hooks/dhcpcd-run-hooks.in --replace /bin/sh ${runtimeShell}
  '';

  configureFlags = [
    "--sysconfdir=/etc"
    "--localstatedir=/var"
    "--disable-privsep"
    "--dbdir=/var/lib/dhcpcd"
    (lib.enableFeature enablePrivSep "privsep")
  ]
  ++ lib.optional enablePrivSep "--privsepuser=dhcpcd";

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  # Hack to make installation succeed.  dhcpcd will still use /var/lib
  # at runtime.
  installFlags = [
    "DBDIR=$(TMPDIR)/db"
    "SYSCONFDIR=${placeholder "out"}/etc"
  ];

  # Check that the udev plugin got built.
  postInstall = lib.optionalString withUdev "[ -e ${placeholder "out"}/lib/dhcpcd/dev/udev.so ]";

  meta = {
    description = "Client for the Dynamic Host Configuration Protocol (DHCP)";
    homepage = "https://roy.marples.name/projects/dhcpcd";
    platforms = lib.platforms.linux;
    license = lib.licenses.bsd2;
    mainProgram = "dhcpcd";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "dhcpcd_project" finalAttrs.version;
  };
})

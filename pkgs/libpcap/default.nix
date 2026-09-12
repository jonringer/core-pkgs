{
  callPackage,
  lib,
  stdenv,
  fetchurl,
  flex,
  bison,
  bash,
  bashNonInteractive,
  bluez,
  libnl,
  libxcrypt,
  pkg-config,
  withBluez ? false,
  withRemote ? false,

  # for passthru.tests
  ettercap ? null,
  nmap,
  ostinato ? null,
  tcpreplay ? null,
  vde2,
  wireshark ? null,
  python3,
  haskellPackages,
}:

stdenv.mkDerivation rec {
  pname = "libpcap";
  version = "1.10.5";

  src = fetchurl {
    url = "https://www.tcpdump.org/release/${pname}-${version}.tar.gz";
    hash = "sha256-N87ZChmjAqfzLkWCJKAMNlwReQXCzTWsVEtogKgUiPA=";
  };

  outputs = [
    "out"
    "lib"
  ];

  buildInputs = [
    bash
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ libnl ]
  ++ lib.optionals withRemote [ libxcrypt ];

  nativeBuildInputs = [
    flex
    bison
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ pkg-config ]
  ++ lib.optionals withBluez [ bluez.dev ];

  # We need to force the autodetection because detection doesn't
  # work in pure build environments.
  configureFlags = [
    "--with-pcap=${if stdenv.hostPlatform.isLinux then "linux" else "bpf"}"
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    "--disable-universal"
  ]
  ++ lib.optionals withRemote [
    "--enable-remote"
  ]
  ++ lib.optionals (stdenv.hostPlatform == stdenv.buildPlatform) [ "ac_cv_linux_vers=2" ];

  postInstall = ''
    if [ "$dontDisableStatic" -ne "1" ]; then
      rm -f $out/lib/libpcap.a
    fi
  '';

  outputChecks.lib.disallowedRequisites = [
    bash
    bashNonInteractive
  ];

  passthru.apple = callPackage ./darwin.nix { };

  passthru.tests = {
    inherit
      nmap
      vde2
      ;
    inherit (python3.pkgs) pcapy-ng scapy;
    haskell-pcap = haskellPackages.pcap;
  }
  // lib.optionalAttrs (ettercap != null) { inherit ettercap; }
  // lib.optionalAttrs (ostinato != null) { inherit ostinato; }
  // lib.optionalAttrs (tcpreplay != null) { inherit tcpreplay; }
  // lib.optionalAttrs (wireshark != null) { inherit wireshark; };

  meta = {
    homepage = "https://www.tcpdump.org";
    description = "Packet Capture Library";
    mainProgram = "pcap-config";
    platforms = lib.platforms.unix;
    license = lib.licenses.bsd3;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "tcpdump" version;
  };
}

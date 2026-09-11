{
  version,
  src-url,
  src-hash,
  useAutoreconf ? false,
  withManpages ? false,
  packageAtLeast,
  packageOlder,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  fetchurl,
  autoreconfHook,
  pkg-config,
  asciidoc,
  xmlto,
  liburcu,
  numactl,
  python3,
  ...
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lttng-ust";
  inherit version;

  src = fetchurl {
    url = src-url;
    hash = src-hash;
  };

  outputs = [
    "bin"
    "out"
    "dev"
    "devdoc"
  ];

  nativeBuildInputs = [
    pkg-config
  ]
  ++ lib.optionals useAutoreconf [ autoreconfHook ]
  ++ lib.optionals withManpages [
    asciidoc
    xmlto
  ];

  buildInputs = [
    numactl
    python3
  ];

  propagatedBuildInputs = [ liburcu ];

  postPatch = lib.optionalString withManpages ''
    substituteInPlace doc/man/Makefile.am \
      --replace-fail '$(XMLTO)' '$(XMLTO) --skip-validation'
  '';

  preConfigure = ''
    patchShebangs .
  '';

  hardeningDisable = lib.optionals (packageOlder "2.13") [ "trivialautovarinit" ];

  configureFlags = [
    "--disable-examples"
  ]
  ++ lib.optionals (packageAtLeast "2.13" && stdenv.hostPlatform.isMusl) [
    "CFLAGS=-Wl,-z,stack-size=2097152"
  ];

  strictDeps = packageAtLeast "2.13";

  meta = {
    description = "LTTng Userspace Tracer libraries";
    mainProgram = "lttng-gen-tp";
    homepage = "https://lttng.org/";
    license = with lib.licenses; [
      lgpl21Only
      gpl2Only
      mit
    ];
    platforms = lib.intersectLists lib.platforms.linux liburcu.meta.platforms;
  };
})

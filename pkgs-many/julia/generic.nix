{
  version,
  src-url,
  src-hash,
  packageAtLeast,
  packageOlder,
  ...
}:

{
  lib,
  stdenv,
  buildPackages,
  fetchurl,
  gfortran,
  m4,
  perl,
  which,
  python3,
  openssl,
  zlib,
  libxml2,
  cacert,
  cmake,
  pkg-config,
  patchelf,
}:

stdenv.mkDerivation {
  pname = "julia";
  inherit version;

  src = fetchurl {
    url = src-url;
    hash = src-hash;
  };

  postPatch = ''
    patchShebangs .
  ''
  + lib.optionalString (packageAtLeast "1.11") ''
    substituteInPlace deps/curl.mk \
      --replace-fail 'jxf $(notdir $<)' \
                     'jxf $(notdir $<) && sed -i "s|/usr/bin/env perl|${lib.getExe buildPackages.perl}|" curl-$(CURL_VER)/scripts/cd2nroff'
  ''
  + lib.optionalString (packageOlder "1.12") ''
    substituteInPlace deps/tools/common.mk \
      --replace-fail "CMAKE_COMMON := " "CMAKE_COMMON := ${lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.10"} "
  ''
  + lib.optionalString (packageAtLeast "1.12") ''
    substituteInPlace deps/openssl.mk \
      --replace-fail 'cd $(dir $<) && $(TAR) -zxf $<' \
                     'cd $(dir $<) && $(TAR) -zxf $< && sed -i "s|/usr/bin/env perl|${lib.getExe buildPackages.perl}|" openssl-$(OPENSSL_VER)/Configure'
  '';

  nativeBuildInputs = [
    gfortran
    m4
    perl
    which
    python3
    openssl
    cmake
    pkg-config
    patchelf
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    gfortran.cc.lib
    libxml2
    zlib
    cacert
  ];

  makeFlags = [
    "prefix=$(out)"
    "USE_BINARYBUILDER=0"
    "BUILD_DOCS=0"
  ]
  ++ lib.optionals stdenv.hostPlatform.isx86_64 [
    "JULIA_CPU_TARGET=generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1)"
  ];

  # Julia's build system expects to build in-tree
  dontUseCmakeConfigure = true;

  doCheck = false;
  doInstallCheck = false;
  dontStrip = true;

  postInstall = ''
    # Remove test files to reduce closure size
    rm -rf $out/share/julia/test

    # Julia-specific cleanup
    find $out/share/julia -name '*.a' -delete
  '';

  # remove forbidden reference to $TMPDIR
  preFixup = ''
    for file in libcurl.so libgmpxx.so libmpfr.so; do
      patchelf --shrink-rpath --allowed-rpath-prefixes ${builtins.storeDir} "$out/lib/julia/$file"
    done
  '';

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
    majorVersion = lib.versions.major version;
    minorVersion = lib.versions.majorMinor version;
  };

  meta = {
    description = "High-level, high-performance dynamic language for technical computing";
    homepage = "https://julialang.org/";
    changelog = "https://github.com/JuliaLang/julia/releases/tag/v${version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "julia";
    timeout = 7200;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "julialang" version;
  };
}

{
  version,
  src-url,
  src-hash,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  llvmPackages,
  openssl,
  pcre2,
  libevent,
  libyaml,
  zlib,
  libxml2,
  gmp,
  boehmgc,
  pkg-config,
}:

stdenv.mkDerivation {
  pname = "crystal";
  inherit version;

  src = fetchurl {
    url = src-url;
    hash = src-hash;
  };

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    llvmPackages.llvm
    openssl
    pcre2
    libevent
    libyaml
    zlib
    libxml2
    gmp
    boehmgc
  ];

  # Crystal binary distribution - no build needed
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r * $out/

    # Wrap crystal to ensure it finds its dependencies
    wrapProgram $out/bin/crystal \
      --prefix PATH : ${
        lib.makeBinPath [
          stdenv.cc
          llvmPackages.llvm
          pkg-config
        ]
      } \
      --set CRYSTAL_LIBRARY_PATH ${
        lib.makeLibraryPath [
          llvmPackages.llvm
          openssl
          pcre2
          libevent
          libyaml
          zlib
          libxml2
          gmp
          boehmgc
        ]
      }

    runHook postInstall
  '';

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
    majorVersion = lib.versions.major version;
    minorVersion = lib.versions.majorMinor version;
  };

  meta = {
    description = "Fast and statically typed, compiled language with Ruby-like syntax";
    homepage = "https://crystal-lang.org/";
    changelog = "https://github.com/crystal-lang/crystal/releases/tag/${version}";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "crystal";
    identifiers.cpeParts = {
      vendor = "crystal-lang";
      product = "crystal";
    };
  };
}

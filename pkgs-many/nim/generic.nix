{
  version,
  src-hash,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  openssl,
  pcre,
  readline,
  boehmgc,
  sqlite,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "nim";
  inherit version;

  src = fetchurl {
    url = "https://nim-lang.org/download/nim-${version}.tar.xz";
    hash = src-hash;
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    openssl
    pcre
    readline
    boehmgc
    sqlite
  ];

  # Set HOME to a writable directory for Nim's cache
  preBuild = ''
    export HOME=$TMPDIR
  '';

  buildPhase = ''
    runHook preBuild

    # Build Nim compiler
    sh build.sh
    ./bin/nim c -d:release koch
    ./koch boot -d:release

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install binaries
    install -Dt $out/bin bin/*

    # Run koch install to copy library files
    ./koch install $out

    # Create symlink to nim binary in nim directory
    ln -sf $out/nim/bin/nim $out/bin/nim

    # Install nimble (Nim package manager)
    cp -r dist/nimble $out/

    # Wrap nim to include runtime dependencies
    wrapProgram $out/bin/nim \
      --prefix PATH : ${lib.makeBinPath [ stdenv.cc ]}

    runHook postInstall
  '';

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
    majorVersion = lib.versions.major version;
    minorVersion = lib.versions.majorMinor version;
  };

  meta = {
    description = "Statically typed compiled systems programming language";
    homepage = "https://nim-lang.org/";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix ++ lib.platforms.darwin;
    mainProgram = "nim";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "nim-lang" version;
  };
})

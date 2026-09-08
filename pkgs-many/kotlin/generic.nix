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
  java,
  unzip,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "kotlin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/JetBrains/kotlin/releases/download/v${version}/kotlin-compiler-${version}.zip";
    hash = src-hash;
  };

  nativeBuildInputs = [
    makeWrapper
    unzip
  ];

  buildInputs = [
    java
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    # The unzip extracts to kotlinc directory
    if [ -d "kotlinc" ]; then
      cp -r kotlinc/* $out/
    else
      cp -r * $out/
    fi

    # Wrap kotlin binaries to use correct JDK (skip .bat files for Windows)
    for prog in $out/bin/*; do
      if [ -f "$prog" ] && [ -x "$prog" ] && [[ ! "$prog" =~ \.bat$ ]]; then
        wrapProgram "$prog" \
          --set JAVA_HOME "${java}" \
          --prefix PATH : "${java}/bin"
      fi
    done

    runHook postInstall
  '';

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
    inherit java;
    majorVersion = lib.versions.major version;
    minorVersion = lib.versions.majorMinor version;
  };

  meta = {
    description = "Statically typed programming language for the JVM, Android, and the browser";
    homepage = "https://kotlinlang.org/";
    changelog = "https://github.com/JetBrains/kotlin/releases/tag/v${version}";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix ++ lib.platforms.darwin;
    mainProgram = "kotlinc";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "jetbrains" version;
  };
})

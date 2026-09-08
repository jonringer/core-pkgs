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
}:

let
  majorVersion = lib.versions.major version;

  # Scala 2 uses the scala/scala repo, Scala 3 uses scala/scala3
  repoName = if majorVersion == "2" then "scala" else "scala3";

  # Scala 3 uses "scala3-" prefix in archive name
  archiveName = if majorVersion == "2" then "scala-${version}.tgz" else "scala3-${version}.tar.gz";

  # Scala 2 needs "v" prefix in tag, Scala 3 doesn't
  tag = if majorVersion == "2" then "v${version}" else version;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "scala";
  inherit version;

  src = fetchurl {
    url = "https://github.com/scala/${repoName}/releases/download/${tag}/${archiveName}";
    hash = src-hash;
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    java
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r bin lib $out/

    # Scala 2 has man and doc directories
    if [ -d man ]; then
      cp -r man $out/
    fi
    if [ -d doc ]; then
      cp -r doc $out/
    fi

    # Scala 3 has libexec, VERSION, and maven2 directories
    if [ -d libexec ]; then
      cp -r libexec $out/
    fi
    if [ -f VERSION ]; then
      cp VERSION $out/
    fi
    if [ -d maven2 ]; then
      cp -r maven2 $out/
    fi

    # Wrap scala binaries to use correct JDK
    for prog in $out/bin/*; do
      if [ -f "$prog" ]; then
        wrapProgram $prog \
          --set JAVA_HOME ${java} \
          --prefix PATH : ${java}/bin
      fi
    done

    runHook postInstall
  '';

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
    inherit java;
    majorVersion = majorVersion;
    minorVersion = lib.versions.majorMinor version;
  };

  meta = {
    description = "General-purpose programming language providing support for functional programming";
    homepage = "https://www.scala-lang.org/";
    changelog = "https://github.com/scala/scala/releases/tag/v${version}";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix ++ lib.platforms.darwin;
    mainProgram = "scala";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "scala-lang" version;
  };
})

{
  version,
  src-hash,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  java,
  rlwrap,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "clojure";
  inherit version;

  src = fetchurl {
    # Clojure Tools distribution (includes CLI scripts and exec.jar)
    url = "https://github.com/clojure/brew-install/releases/download/${version}/clojure-tools-${version}.tar.gz";
    hash = src-hash;
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    java
    rlwrap
  ];

  dontBuild = true;

  # Based on https://github.com/clojure/brew-install/blob/master/src/main/resources/clojure/install/linux-install.sh
  installPhase =
    let
      binPath = lib.makeBinPath [
        rlwrap
        java
      ];
    in
    ''
      runHook preInstall

      clojure_lib_dir=$out
      bin_dir=$out/bin

      echo "Installing libs into $clojure_lib_dir"
      install -Dm644 deps.edn "$clojure_lib_dir/deps.edn"
      install -Dm644 example-deps.edn "$clojure_lib_dir/example-deps.edn"
      install -Dm644 tools.edn "$clojure_lib_dir/tools.edn"
      install -Dm644 exec.jar "$clojure_lib_dir/libexec/exec.jar"
      install -Dm644 clojure-tools-${version}.jar "$clojure_lib_dir/libexec/clojure-tools-${version}.jar"

      echo "Installing clojure and clj into $bin_dir"
      substituteInPlace clojure --replace PREFIX $out
      substituteInPlace clj --replace BINDIR $bin_dir
      install -Dm755 clojure "$bin_dir/clojure"
      install -Dm755 clj "$bin_dir/clj"

      wrapProgram $bin_dir/clojure --prefix PATH : $out/bin:${binPath}
      wrapProgram $bin_dir/clj --prefix PATH : $out/bin:${binPath}

      runHook postInstall
    '';

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
    inherit java;
    majorVersion = lib.versions.major version;
    minorVersion = lib.versions.majorMinor version;
  };

  meta = {
    description = "Dynamic, functional programming language that runs on the JVM";
    homepage = "https://clojure.org/";
    changelog = "https://github.com/clojure/clojure/blob/clojure-${version}/changes.md";
    license = lib.licenses.epl10;
    platforms = lib.platforms.unix ++ lib.platforms.darwin;
    mainProgram = "clojure";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "clojure" version;
  };
})

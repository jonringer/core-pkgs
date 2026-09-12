{
  version,
  src-hash,
  minimumOTPVersion,
  erlangVariant ? null,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  erlang,
  coreutils,
  curl,
  bash,
}:

let
  # Select a compatible Erlang/OTP version.
  # When erlangVariant is set, pick that specific variant from the erlang
  # package set (e.g. "v26" -> erlang.v26) instead of using the default,
  # which may be a newer OTP release than this Elixir version supports.
  compatibleErlang = if erlangVariant != null then erlang.${erlangVariant} else erlang;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "elixir";
  inherit version;

  src = fetchurl {
    url = "https://github.com/elixir-lang/elixir/archive/v${version}.tar.gz";
    hash = src-hash;
  };

  nativeBuildInputs = [
    compatibleErlang
    makeWrapper
  ];

  env = {
    LANG = "C.UTF-8";
    LC_TYPE = "C.UTF-8";
    DESTDIR = placeholder "out";
    PREFIX = "/";
    ERL_COMPILER_OPTIONS = "[deterministic]";
  };

  preBuild = ''
    patchShebangs lib/elixir/scripts/generate_app.escript || true
  '';

  # copy stdlib source files for LSP access
  postInstall = ''
    for d in lib/*; do
      cp -R "$d/lib" "$out/lib/elixir/$d"
    done
  '';

  postFixup = ''
    # Elixir binaries are shell scripts which run erl. Add some stuff
    # to PATH so the scripts can run without problems.

    for f in $out/bin/*; do
      b=$(basename $f)
      if [ "$b" = mix ]; then continue; fi
      wrapProgram $f \
        --prefix PATH ":" "${
          lib.makeBinPath [
            compatibleErlang
            coreutils
            curl
            bash
          ]
        }"
    done

    substituteInPlace $out/bin/mix \
      --replace-warn "/usr/bin/env elixir" "$out/bin/elixir"
  '';

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
    erlang = compatibleErlang;
    majorVersion = lib.versions.major version;
    minorVersion = lib.versions.majorMinor version;
  };

  meta = {
    description = "Functional, concurrent, general-purpose programming language that runs on the BEAM VM";
    homepage = "https://elixir-lang.org/";
    changelog = "https://github.com/elixir-lang/elixir/releases/tag/v${version}";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix ++ lib.platforms.darwin;
    mainProgram = "elixir";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "elixir-lang" version;
  };
})

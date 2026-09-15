{
  stdenv,
  lib,
  R,
  gettext,
  gfortran,
}:

{
  buildInputs ? [ ],
  ...
}@attrs:

stdenv.mkDerivation (
  {
    buildInputs = buildInputs ++ [
      R
      gettext
    ];

    configurePhase = ''
      runHook preConfigure
      export MAKEFLAGS+="''${enableParallelBuilding:+-j$NIX_BUILD_CORES}"
      export R_LIBS_SITE="$R_LIBS_SITE''${R_LIBS_SITE:+:}$out/library"
      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      runHook postBuild
    '';

    installFlags = if attrs.doCheck or true then [ ] else [ "--no-test-load" ];

    rCommand = "R";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/library"

      # R expands configure arguments through a shell, so quote each array
      # element before passing the result as a single --configure-args value.
      local configureArgs=""
      if ((''${#configureFlags[@]})); then
        printf -v configureArgs '%q ' "''${configureFlags[@]}"
      fi

      $rCommand CMD INSTALL \
        --built-timestamp='1970-01-01 00:00:00 UTC' \
        --configure-args="$configureArgs" \
        "''${installFlags[@]}" \
        -l "$out/library" \
        .
      runHook postInstall
    '';

    postFixup = ''
      if test -e $out/nix-support/propagated-build-inputs; then
          ln -s $out/nix-support/propagated-build-inputs $out/nix-support/propagated-user-env-packages
      fi
    '';

    checkPhase = ''
      # noop since R CMD INSTALL tests packages
    '';
  }
  // attrs
  // {
    name = "r-${attrs.name or "${attrs.pname}-${attrs.version}"}";
  }
)

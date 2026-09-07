{
  version,
  hashes,
  ...
}:

{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  unzip,
  installShellFiles,
  makeWrapper,
  openssl,
}:

let
  sources = builtins.mapAttrs (
    system: hash:
    let
      arch = builtins.elemAt (lib.splitString "-" system) 0;
      os = builtins.elemAt (lib.splitString "-" system) 1;
      platformStr =
        {
          "aarch64-darwin" = "darwin-aarch64";
          "aarch64-linux" = "linux-aarch64";
          "x86_64-linux" = "linux-x64";
        }
        .${system};
    in
    fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-${platformStr}.zip";
      inherit hash;
    }
  ) hashes;
in
stdenvNoCC.mkDerivation {
  pname = "bun";
  inherit version;

  src =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  sourceRoot =
    {
      aarch64-darwin = "bun-darwin-aarch64";
    }
    .${stdenvNoCC.hostPlatform.system} or null;

  nativeBuildInputs = [
    unzip
    installShellFiles
    makeWrapper
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = [ openssl ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm 755 ./bun $out/bin/bun
    ln -s $out/bin/bun $out/bin/bunx

    runHook postInstall
  '';

  postPhases = [ "postPatchelf" ];
  postPatchelf = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installShellCompletion --cmd bun \
      --bash <(SHELL="bash" $out/bin/bun completions) \
      --zsh <(SHELL="zsh" $out/bin/bun completions) \
      --fish <(SHELL="fish" $out/bin/bun completions)
  '';

  passthru = {
    ekapkgs-update.platform-hashes = [
      "x86_64-linux"
      "aarch64-linux"
      # TODO(corepkgs) support darwin
      # "x86_64-darwin"
      # "aarch64-darwin"
    ];
  };

  meta = {
    homepage = "https://bun.sh";
    changelog = "https://bun.sh/blog/bun-v${version}";
    description = "Incredibly fast JavaScript runtime, bundler, transpiler and package manager – all in one";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = with lib.licenses; [
      mit
      lgpl21Only
    ];
    mainProgram = "bun";
    platforms = builtins.attrNames sources;
    broken = stdenvNoCC.hostPlatform.isMusl;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "oven" version;
  };
}

{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  pandoc ? null,
  runCommand,
  nix-update-script,
}:

# TODO: make it default implementataion of yq

buildGoModule (finalAttrs: {
  pname = "yq-go";
  version = "4.53.6";

  src = fetchFromGitHub {
    owner = "mikefarah";
    repo = "yq";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BLd6NaYBEuTYSCe0mTX2FYER+ybT4KqGsHw86re7wiU=";
  };

  vendorHash = "sha256-q/khSpZgo8D3K8adjI56Xj943vdWbGgnzG619NWrLY0=";

  # TestFormatStringFromFilename expects "unknown" for unrecognized extensions,
  # but upstream changed the default to "yaml"
  checkFlags = [
    "-run"
    "^(?!TestFormatStringFromFilename$)"
  ];

  nativeBuildInputs = lib.optionals (stdenv.buildPlatform.canExecute stdenv.hostPlatform) [
    installShellFiles
    pandoc
  ];

  postInstall =
    lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      installShellCompletion --cmd yq \
        --bash <($out/bin/yq shell-completion bash) \
        --fish <($out/bin/yq shell-completion fish) \
        --zsh <($out/bin/yq shell-completion zsh)
    ''
    + lib.optionalString (pandoc != null) ''
      patchShebangs ./scripts/generate-man-page*
      export MAN_HEADER="yq (https://github.com/mikefarah/yq/) version ${finalAttrs.version}"
      ./scripts/generate-man-page-md.sh
      ./scripts/generate-man-page.sh
      installManPage yq.1
    '';

  passthru = {
    tests = {
      simple = runCommand "yq-go-test" { } ''
        echo "test: 1" | ${finalAttrs.finalPackage}/bin/yq eval -j > $out
        [ "$(cat $out | tr -d $'\n ')" = '{"test":1}' ]
      '';
    };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Portable command-line YAML processor";
    homepage = "https://mikefarah.gitbook.io/yq/";
    changelog = "https://github.com/mikefarah/yq/raw/${finalAttrs.src.tag}/release_notes.txt";
    mainProgram = "yq";
    license = [ lib.licenses.mit ];
  };
})

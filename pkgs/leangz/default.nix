{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "leangz";
  version = "0.1.20";

  src = fetchFromGitHub {
    owner = "digama0";
    repo = "leangz";
    tag = "v${finalAttrs.version}";
    hash = "sha256-EDei1ykLtjj8Qd9soL2p0h8lL+wQOgi5vQGWDbf1NK4=";
  };

  cargoHash = "sha256-h0cbvqmX5p0/Me6kPKpcuMUcVivII2n4Z0D/DNyAVDI=";

  meta = {
    description = "Lean 4 .olean file (de)compressor";
    homepage = "https://github.com/digama0/leangz";
    license = lib.licenses.asl20;
    mainProgram = "leantar";
  };
})

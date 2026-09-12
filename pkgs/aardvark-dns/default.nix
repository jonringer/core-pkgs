{
  lib,
  rustPlatform,
  fetchFromGitHub,
  testers,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "aardvark-dns";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "aardvark-dns";
    tag = "v${finalAttrs.version}";
    hash = "sha256-EQFTkJQaW4f6AFmMP5h24ugK5st1rg9c/QK3WjBORAQ=";
  };

  cargoHash = "sha256-nTcAuhfez2ub+4z9E2YGp5i+JJr9K/PpG22ZvMW5ni4=";

  passthru.tests = {
    version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "aardvark-dns --version";
    };
  };

  meta = {
    changelog = "https://github.com/containers/aardvark-dns/releases/tag/${finalAttrs.src.rev}";
    description = "Authoritative dns server for A/AAAA container records";
    homepage = "https://github.com/containers/aardvark-dns";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "aardvark-dns";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "aardvark-dns_project" finalAttrs.version;
  };
})

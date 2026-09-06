{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  mandown,
  protobuf,
  go-md2man,
  testers,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "netavark";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "netavark";
    rev = "v${finalAttrs.version}";
    hash = "sha256-nTmbPKTIne4iIrX5KPWTkFc+SD1Th9/sOciAzThin9M=";
  };

  cargoHash = "sha256-6ZYVQVLm9b71s5FPgTSzDmscEVLE9ZxKCg+4R+0hkUk=";

  nativeBuildInputs = [
    installShellFiles
    mandown
    protobuf
    go-md2man
  ];

  postBuild = ''
    make -C docs netavark.1
    installManPage docs/netavark.1
  '';

  passthru.tests = {
    version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "netavark --version";
    };
  };

  meta = {
    changelog = "https://github.com/containers/netavark/releases/tag/${finalAttrs.src.rev}";
    description = "Rust based network stack for containers";
    homepage = "https://github.com/containers/netavark";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "netavark_project" finalAttrs.version;
  };
})

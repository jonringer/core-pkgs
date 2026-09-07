{
  lib,
  fetchFromGitHub,
  buildGoModule,
  go-md2man,
  installShellFiles,
  pkg-config,
  which,
  libapparmor,
  libseccomp,
  libselinux,
  stdenv,
  makeBinaryWrapper,
  runc,
  testers,
}:

buildGoModule (finalAttrs: {
  pname = "runc";
  version = "1.5.1";

  src = fetchFromGitHub {
    owner = "opencontainers";
    repo = "runc";
    tag = "v${finalAttrs.version}";
    hash = "sha256-N059CtWkenSXYksVu5Uh+sGodC+JHc91R56b+VoC96k=";
  };

  vendorHash = null;
  outputs = [
    "out"
    "man"
  ];

  nativeBuildInputs = [
    go-md2man
    installShellFiles
    makeBinaryWrapper
    pkg-config
    which
  ];

  buildInputs = [
    libselinux
    libseccomp
    libapparmor
  ];

  makeFlags = [
    "BUILDTAGS+=seccomp"
    "SHELL=${stdenv.shell}"
  ];

  buildPhase = ''
    runHook preBuild
    patchShebangs .
    make ${toString finalAttrs.makeFlags} runc man
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 runc $out/bin/runc
    installManPage man/*/*.[1-9]
    wrapProgram $out/bin/runc \
      --prefix PATH : /run/current-system/systemd/bin
    runHook postInstall
  '';

  passthru.tests = {
    version = testers.testVersion {
      package = runc;
      command = "runc --version";
    };
  };

  meta = {
    homepage = "https://github.com/opencontainers/runc";
    description = "CLI tool for spawning and running containers according to the OCI specification";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "runc";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "linuxfoundation" finalAttrs.version;
  };
})

{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "lego";
  version = "5.4.1";

  src = fetchFromGitHub {
    owner = "go-acme";
    repo = "lego";
    rev = "v${finalAttrs.version}";
    hash = "sha256-LEPx725uvHUH5E5H8dwvOG0JA7DByZs0/DHHGC/nMJI=";
  };

  vendorHash = "sha256-6lvowCEYf++CIJz+AZ6ZIQC0WZxqIj7ygAoOpN01rns=";

  doCheck = false;

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  meta = {
    description = "Let's Encrypt client and ACME library written in Go";
    homepage = "https://go-acme.github.io/lego/";
    license = lib.licenses.mit;
    mainProgram = "lego";
  };
})

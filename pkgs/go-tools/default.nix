{
  buildGoModule,
  lib,
  fetchFromGitHub,
  testers,
}:

buildGoModule (finalAttrs: {
  pname = "go-tools";
  version = "2026.2.1";

  src = fetchFromGitHub {
    owner = "dominikh";
    repo = "go-tools";
    rev = finalAttrs.version;
    sha256 = "sha256-wellofnfLW4lQy68UQyFJfvrKCfrZ/EllLODX1g9taY=";
  };

  vendorHash = "sha256-3no4wPqFG0RfSsWB0z8EYxeoZ30t+Zf7ZayzFCLEm2A=";

  excludedPackages = [
    "website"
    "staticcheck/sa5000"
  ];

  passthru.tests = {
    version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "staticcheck -version";
    };
  };

  meta = {
    description = "Collection of tools and libraries for working with Go code, including linters and static analysis";
    homepage = "https://staticcheck.io";
    license = lib.licenses.mit;
  };
})

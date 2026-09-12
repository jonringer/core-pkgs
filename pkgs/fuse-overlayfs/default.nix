{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  fuse,
  testers,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fuse-overlayfs";
  version = "1.18";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "fuse-overlayfs";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Us7FKKJrZH5l+NRIEw2b3RTAGw08YfsIBauwH866P8E=";
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

  buildInputs = [ fuse ];

  outputs = [
    "out"
    "man"
  ];

  passthru.tests = {
    version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "fuse-overlayfs --version";
    };
  };

  meta = {
    description = "FUSE implementation for overlayfs";
    longDescription = "An implementation of overlay+shiftfs in FUSE for rootless containers.";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
    inherit (finalAttrs.src.meta) homepage;
    mainProgram = "fuse-overlayfs";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "fuse-overlayfs_project" finalAttrs.version;
  };
})

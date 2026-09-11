{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "jigd";
  version = "0-unstable-2026-09-10";

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "repkgs";
    rev = "1cd7b8b03526f35d45dc66c94c1e1b63d0e636ca";
    hash = "sha256-5Z94QJiwg9PqVHlMSHJ/yqk36WpJD9RL2JmfgBBtRsA=";
  };

  modRoot = "pkgs/ji/jigd/src";

  vendorHash = "sha256-3TfQeKs/DJTm/h0QASqCPrpfGTfeTpnjaLak9eSWjz8=";

  env.CGO_ENABLED = "0";

  ldflags = [ "-s" ];

  meta = {
    description = "Host-side compilation cache daemon for jig";
    homepage = "https://github.com/Mic92/repkgs";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "jigd";
  };
})

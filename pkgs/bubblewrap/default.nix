{
  lib,
  stdenv,
  fetchFromGitHub,
  docbook-xsl,
  libxslt,
  meson,
  ninja,
  pkg-config,
  bash-completion,
  libcap,
  libselinux,
  testers,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bubblewrap";
  version = "0.12.0";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "bubblewrap";
    rev = "v${finalAttrs.version}";
    hash = "sha256-VnhJ5bej3/GTHcU8+AkyR7f3J0KKDuoc94SFxo4grhk=";
  };

  outputs = [
    "out"
    "dev"
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error=format-overflow";

  postPatch = ''
    substituteInPlace tests/libtest.sh \
      --replace "/var/tmp" "$TMPDIR"
  '';

  nativeBuildInputs = [
    docbook-xsl
    libxslt
    meson
    meson.configurePhaseHook
    ninja
    pkg-config
  ];

  buildInputs = [
    bash-completion
    libcap
    libselinux
  ];

  # incompatible with Nix sandbox
  doCheck = false;

  passthru.tests = {
    version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "bwrap --version";
    };
  };

  meta = {
    changelog = "https://github.com/containers/bubblewrap/releases/tag/${finalAttrs.src.rev}";
    description = "Unprivileged sandboxing tool";
    homepage = "https://github.com/containers/bubblewrap";
    license = lib.licenses.lgpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "bwrap";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "projectatomic" finalAttrs.version;
  };
})

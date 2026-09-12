{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  gnutls,
  cunit ? null,
  ncurses,
  knot-dns ? null,
  curl,
  runUnitTests,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ngtcp2";
  version = "1.25.0";

  src = fetchFromGitHub {
    owner = "ngtcp2";
    repo = "ngtcp2";
    rev = "v${finalAttrs.version}";
    hash = "sha256-BBV4nNtSWQOFuwVOeH3LJEUeF7v4LVhGbfcrkroBAvc=";
  };

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];
  buildInputs = [ gnutls ];

  configureFlags = [ "--with-gnutls=yes" ];

  nativeCheckInputs =
    lib.optional (cunit != null) cunit ++ lib.optional stdenv.hostPlatform.isDarwin ncurses;

  passthru.tests = lib.optionalAttrs (knot-dns != null) (knot-dns.passthru.tests or { }) // {
    unittests = runUnitTests finalAttrs.finalPackage;
    curlWithGnuTls = curl.gnutls;
  };

  meta = {
    homepage = "https://github.com/ngtcp2/ngtcp2";
    description = "Effort to implement RFC9000 QUIC protocol";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})

/*
  Why split from ./default.nix?

  ngtcp2 libs contain helpers to plug into various crypto libs (gnutls, patched openssl, ...).
  Building multiple of them while keeping closures separable would be relatively complicated.
  Separating the builds is easier for now; the missed opportunity to share the 0.3--0.4 MB
  library isn't such a big deal.

  Moreover upstream still commonly does incompatible changes, so agreeing
  on a single version might be hard sometimes.  That's why it seemed simpler
  to completely separate the nix expressions, too.
*/

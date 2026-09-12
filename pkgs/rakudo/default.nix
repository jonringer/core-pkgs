{
  fetchFromGitHub,
  lib,
  nqp,
  perl,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "rakudo";
  version = "2026.08";

  src = fetchFromGitHub {
    owner = "rakudo";
    repo = "rakudo";
    tag = finalAttrs.version;
    fetchSubmodules = true;
    hash = "sha256-Nr4YyjXPAdGj+EXSFrfzFYgn3NQtR8GgVMv1eegAsxI=";
  };

  postPatch = ''
    substituteInPlace src/core.c/CompUnit/Repository/Installation.rakumod \
      --subst-var out
  '';

  patches = [
    ./rakudo-plain-wrapper.patch
  ];

  configureScript = "${lib.getExe perl} ./Configure.pl";
  configureFlags = [
    "--backends=moar"
    "--with-nqp=${lib.getExe nqp}"
  ];

  meta = {
    description = "Raku implementation on top of Moar virtual machine";
    homepage = "https://rakudo.org";
    license = lib.licenses.artistic2;
    platforms = lib.platforms.unix;
    mainProgram = "rakudo";
  };
})

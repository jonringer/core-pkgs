{
  fetchFromGitHub,
  lib,
  moarvm,
  perl,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "nqp";
  version = "2026.08";

  src = fetchFromGitHub {
    owner = "Raku";
    repo = "nqp";
    tag = finalAttrs.version;
    fetchSubmodules = true;
    hash = "sha256-T1iMw25Fukjvbv2TAi/kp/1dCHDe6kvHwckbpP3E3f8=";
  };

  configureScript = "${lib.getExe perl} ./Configure.pl";
  configureFlags = [
    "--backends=moar"
    "--with-moar=${lib.getExe moarvm}"
  ];

  # nqp expects to find files from moarvm in the same output
  preBuild = ''
    share_dir="share/nqp/lib/MAST"
    mkdir -p $out/$share_dir
    ln -fs ${moarvm}/$share_dir/{Nodes,Ops}.nqp $out/$share_dir
  '';

  meta = {
    description = "Lightweight Raku-like environment for virtual machines";
    homepage = "https://github.com/Raku/nqp";
    license = lib.licenses.artistic2;
    platforms = lib.platforms.unix;
    mainProgram = "nqp";
  };
})

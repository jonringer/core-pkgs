{
  lib,
  stdenv,
  makeWrapper,
  bash,
  coreutils,
  sed,
  cvs ? null,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "nix-prefetch-cvs";
  version = "1.0.0";

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash ];

  dontUnpack = true;

  installPhase = ''
    install -vD ${./nix-prefetch-cvs.sh} $out/bin/$pname;
    wrapProgram $out/bin/$pname --prefix PATH : ${
      lib.makeBinPath [
        cvs
        coreutils
        sed
      ]
    } --set HOME /homeless-shelter
  '';

  preferLocalBuild = true;

  meta = {
    description = "Script used to obtain source hashes for fetchcvs";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.unix;
    mainProgram = "nix-prefetch-cvs";
    broken = cvs == null;
  };
})

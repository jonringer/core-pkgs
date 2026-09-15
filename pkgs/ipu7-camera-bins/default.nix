{
  lib,
  stdenv,
  fetchFromGitHub,
  autoPatchelfHook,
  expat,
  zlib,
}:

stdenv.mkDerivation {
  pname = "ipu7-camera-bins";
  version = "unstable-2026-06-29";

  src = fetchFromGitHub {
    owner = "intel";
    repo = "ipu7-camera-bins";
    tag = "20260629_2";
    hash = "sha256-LjiqxlQKDLArgK2puxlyTpLPtL6QN6P/xWO2asPTLig=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    (lib.getLib stdenv.cc.cc)
    expat
    zlib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp --no-preserve=mode --recursive \
      lib \
      include \
      $out/

    runHook postInstall
  '';

  postFixup = ''
    for lib in $out/lib/lib*.so.*; do \
      lib=''${lib##*/}; \
      ln -sf $lib $out/lib/''${lib%.*}; \
    done

    for pcfile in $out/lib/pkgconfig/*.pc; do
      substituteInPlace $pcfile \
        --replace 'prefix=/usr' "prefix=$out"
    done
  '';

  meta = {
    description = "IPU7 firmware and proprietary image processing libraries for Lunar Lake";
    homepage = "https://github.com/intel/ipu7-camera-bins";
    license = lib.licenses.issl;
    sourceProvenance = with lib.sourceTypes; [
      binaryFirmware
    ];
    platforms = [ "x86_64-linux" ];
  };
}

{
  lib,
  stdenv,
  fetchFromGitHub,
  autoPatchelfHook,
  expat,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ipu6-camera-bins";
  version = "unstable-2025-06-27";

  src = fetchFromGitHub {
    repo = "ipu6-camera-bins";
    owner = "intel";
    tag = "20250923_ov02e";
    hash = "sha256-YPPzuK13o2jnRSB3ORoMUU5E9/IifKVSetAqZHRofhw=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    (lib.getLib stdenv.cc.cc)
    expat
    zlib
  ];

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
      ln -s $lib $out/lib/''${lib%.*}; \
    done

    for pcfile in $out/lib/pkgconfig/*.pc; do
      substituteInPlace $pcfile \
        --replace 'prefix=/usr' "prefix=$out"
    done
  '';

  meta = {
    description = "IPU firmware and proprietary image processing libraries";
    homepage = "https://github.com/intel/ipu6-camera-bins";
    license = lib.licenses.issl;
    sourceProvenance = with lib.sourceTypes; [
      binaryFirmware
    ];
    platforms = [ "x86_64-linux" ];
  };
})

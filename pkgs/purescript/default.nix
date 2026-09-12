# purescript — Strongly-typed functional programming language (pre-built binary)
{
  stdenv,
  lib,
  fetchurl,
  zlib,
  gmp,
}:

let
  dynamic-linker = stdenv.cc.bintools.dynamicLinker;

  patchelf =
    libPath:
    lib.optionalString (!stdenv.hostPlatform.isDarwin) ''
      if patchelf --print-interpreter $PURS &>/dev/null; then
        chmod u+w $PURS
        patchelf --interpreter ${dynamic-linker} --set-rpath ${libPath} $PURS
        chmod u-w $PURS
      fi
    '';
in
stdenv.mkDerivation rec {
  pname = "purescript";
  version = "0.15.16";

  src =
    let
      url = "https://github.com/${pname}/${pname}/releases/download/v${version}/";
      sources = {
        "x86_64-linux" = fetchurl {
          url = url + "linux64.tar.gz";
          sha256 = "sha256-RNqe+4pOFFGej9U1Csw3ekuYHkI1GnjFPp+EBFvzjiI=";
        };
        "aarch64-linux" = fetchurl {
          url = url + "linux-arm64.tar.gz";
          sha256 = "1ws5h337xq0l06zrs9010h6wj2hq5cqk5ikp9arq7hj7lxf43vn5";
        };
      };
    in
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  buildInputs = [
    zlib
    gmp
  ];
  libPath = lib.makeLibraryPath buildInputs;
  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin
    PURS="$out/bin/purs"

    install -D -m555 -T purs $PURS
    ${patchelf libPath}
  '';

  meta = {
    description = "Strongly-typed functional programming language that compiles to JavaScript";
    homepage = "https://www.purescript.org/";
    license = lib.licenses.bsd3;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "purs";
  };
}

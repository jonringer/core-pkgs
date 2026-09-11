{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  icu,
  zlib,
  libkrb5,
  openssl,
  curl,
  lttng-ust,
  installShellFiles,
}:

let
  version = "9.0.19";

  srcs = {
    x86_64-linux = {
      url = "https://builds.dotnet.microsoft.com/dotnet/Runtime/${version}/dotnet-runtime-${version}-linux-x64.tar.gz";
      hash = "sha512-5/ypxafvoufa1rpgFQnGhO9Gcn46sfClGjddDf8m+gbwAe7IggM900pqEEl68w8A/wAGbBZeALHhPX2i3PXUQQ==";
    };
    aarch64-linux = {
      url = "https://builds.dotnet.microsoft.com/dotnet/Runtime/${version}/dotnet-runtime-${version}-linux-arm64.tar.gz";
      hash = "sha512-4HUQxkn+3z+xPdIQJvNMi80X9Upo5MBxoSh9JuEH4J2czRPvD2PGMNMJuLeXMQqNxCrtalUesUXZ+thqWBmk7g==";
    };
    aarch64-darwin = {
      url = "https://builds.dotnet.microsoft.com/dotnet/Runtime/${version}/dotnet-runtime-${version}-osx-arm64.tar.gz";
      hash = "sha512-b/ZoOHtaJihAiHa3TkklsO5xTz26P8eVHS0/sPypaYarzzYTpikQMZ6EV/Z0zU3dLqWp5yJgDtUdxVGBMKDBhQ==";
    };
  };
in
stdenv.mkDerivation {
  pname = "dotnet-runtime";
  inherit version;

  src = fetchurl (
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}")
  );

  sourceRoot = ".";

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;

  buildInputs = [
    stdenv.cc.cc
    zlib
    icu
    libkrb5
    curl
    openssl
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux lttng-ust.v2_12;

  dontPatchELF = true;
  noDumpEnvVars = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/doc/dotnet-runtime/${version}
    mv LICENSE.txt $out/share/doc/dotnet-runtime/${version}/
    mv ThirdPartyNotices.txt $out/share/doc/dotnet-runtime/${version}/

    mkdir -p $out/share/dotnet
    cp -r ./ $out/share/dotnet

    mkdir -p $out/bin
    ln -s $out/share/dotnet/dotnet $out/bin/dotnet

    runHook postInstall
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf \
      --add-needed libicui18n.so \
      --add-needed libicuuc.so \
      $out/share/dotnet/shared/Microsoft.NETCore.App/*/libcoreclr.so \
      $out/share/dotnet/shared/Microsoft.NETCore.App/*/*System.Globalization.Native.so
    patchelf \
      --add-needed libgssapi_krb5.so \
      $out/share/dotnet/shared/Microsoft.NETCore.App/*/*System.Net.Security.Native.so
    patchelf \
      --add-needed libssl.so \
      $out/share/dotnet/shared/Microsoft.NETCore.App/*/*System.Security.Cryptography.Native.OpenSsl.so
  '';

  meta = {
    description = ".NET Runtime ${version}";
    homepage = "https://dotnet.github.io/";
    license = lib.licenses.mit;
    mainProgram = "dotnet";
    platforms = builtins.attrNames srcs;
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
  };
}

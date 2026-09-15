{
  lib,
  stdenvNoCC,
  dotnet-sdk ? throw "buildDotnetModule requires dotnet-sdk which is not yet available in core-pkgs",
  dotnet-runtime ? dotnet-sdk,
  makeWrapper,
}:

attrs:

let
  pname = attrs.pname;
  version = attrs.version;
  src = attrs.src;
  nugetDeps = attrs.nugetDeps or null;
  projectFile = attrs.projectFile or null;
  dotnetFlags = attrs.dotnetFlags or [ ];
  dotnetBuildFlags = attrs.dotnetBuildFlags or [ ];
  dotnetInstallFlags = attrs.dotnetInstallFlags or [ ];
  dotnetRestoreFlags = attrs.dotnetRestoreFlags or [ ];
  executables = attrs.executables or null;
  runtimeDeps = attrs.runtimeDeps or [ ];
  buildType = attrs.buildType or "Release";

  remainingArgs = removeAttrs attrs [
    "nugetDeps"
    "projectFile"
    "dotnetFlags"
    "dotnetBuildFlags"
    "dotnetInstallFlags"
    "dotnetRestoreFlags"
    "executables"
    "runtimeDeps"
    "buildType"
    "selfContainedBuild"
    "useAppHost"
    "useDotnetFromEnv"
  ];

  projectFlag =
    if projectFile != null then
      lib.concatMapStringsSep " " (p: ''"${p}"'') (lib.toList projectFile)
    else
      "";
in
stdenvNoCC.mkDerivation (
  remainingArgs
  // {
    inherit pname version src;

    nativeBuildInputs = (remainingArgs.nativeBuildInputs or [ ]) ++ [
      dotnet-sdk
      makeWrapper
    ];

    buildInputs = (remainingArgs.buildInputs or [ ]) ++ runtimeDeps;

    configurePhase =
      remainingArgs.configurePhase or ''
        runHook preConfigure
        export DOTNET_CLI_TELEMETRY_OPTOUT=1
        export DOTNET_NOLOGO=1
        ${lib.optionalString (nugetDeps != null) ''
          dotnet restore ${projectFlag} \
            ${lib.concatStringsSep " " dotnetFlags} \
            ${lib.concatStringsSep " " dotnetRestoreFlags}
        ''}
        runHook postConfigure
      '';

    buildPhase =
      remainingArgs.buildPhase or ''
        runHook preBuild
        dotnet build ${projectFlag} \
          -c ${buildType} \
          --no-restore \
          ${lib.concatStringsSep " " dotnetFlags} \
          ${lib.concatStringsSep " " dotnetBuildFlags}
        runHook postBuild
      '';

    installPhase =
      remainingArgs.installPhase or ''
        runHook preInstall
        dotnet publish ${projectFlag} \
          -c ${buildType} \
          -o $out/lib/${pname} \
          --no-build \
          ${lib.concatStringsSep " " dotnetFlags} \
          ${lib.concatStringsSep " " dotnetInstallFlags}
        ${lib.optionalString (executables != null) ''
          mkdir -p $out/bin
          ${lib.concatMapStringsSep "\n" (exe: "makeWrapper $out/lib/${pname}/${exe} $out/bin/${exe}") (
            lib.toList executables
          )}
        ''}
        runHook postInstall
      '';
  }
)

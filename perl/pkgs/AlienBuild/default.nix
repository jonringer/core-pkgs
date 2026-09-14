{
  buildPerlPackage,
  fetchurl,
  CaptureTiny,
  DevelHide,
  FFICheckLib,
  FileWhich,
  Filechdir,
  PathTiny,
  PkgConfig,
  Test2Suite,
}:

buildPerlPackage {
  pname = "Alien-Build";
  version = "2.80";
  src = fetchurl {
    url = "mirror://cpan/authors/id/P/PL/PLICEASE/Alien-Build-2.80.tar.gz";
    hash = "sha256-2e3JNrBnBbtcte5aLqi89hEaPogVkU8XfhXjwP7TAfM=";
  };

  # override default postPatch to avoid patchShebangs breaking tests
  postPatch = "";

  propagatedBuildInputs = [
    CaptureTiny
    FFICheckLib
    FileWhich
    Filechdir
    PathTiny
    PkgConfig
  ];
  buildInputs = [
    DevelHide
    Test2Suite
  ];
  meta = {
    description = "Build external dependencies for use in CPAN";
  };
}

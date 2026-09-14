{
  buildPerlPackage,
  fetchurl,
  lib,
  pkg-config,
  libxml2,
  AlienBuild,
  AlienBuildPluginDownloadGitLab,
  MojoDOM58,
  SortVersions,
  Test2Suite,
  URI,
}:

buildPerlPackage {
  pname = "Alien-Libxml2";
  version = "0.19";
  src = fetchurl {
    url = "mirror://cpan/authors/id/P/PL/PLICEASE/Alien-Libxml2-0.19.tar.gz";
    hash = "sha256-9KZ0CZu9V0fAw7derYQfOyRJNdnvQro1NoAkvWERdMk=";
  };
  strictDeps = true;
  nativeBuildInputs = [ pkg-config ];
  propagatedBuildInputs = [ AlienBuild ];
  buildInputs = [
    libxml2
    AlienBuildPluginDownloadGitLab
    MojoDOM58
    SortVersions
    Test2Suite
    URI
  ];
  meta = {
    description = "Install the C libxml2 library on your system";
  };
}

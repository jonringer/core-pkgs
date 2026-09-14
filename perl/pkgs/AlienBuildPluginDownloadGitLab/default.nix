{
  buildPerlPackage,
  fetchurl,
  AlienBuild,
  PathTiny,
  Test2Suite,
  URI,
}:

buildPerlPackage {
  pname = "Alien-Build-Plugin-Download-GitLab";
  version = "0.01";
  src = fetchurl {
    url = "mirror://cpan/authors/id/P/PL/PLICEASE/Alien-Build-Plugin-Download-GitLab-0.01.tar.gz";
    hash = "sha256-wfCJyOoVKniZCdSKg9v88mJvdz2vMEMchiJYKyarqQI=";
  };
  buildInputs = [ Test2Suite ];
  propagatedBuildInputs = [
    AlienBuild
    PathTiny
    URI
  ];
  meta = {
    description = "Alien::Build plugin to download from GitLab";
  };
}

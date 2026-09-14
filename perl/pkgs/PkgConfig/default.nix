{
  buildPerlPackage,
  fetchurl,
}:

buildPerlPackage rec {
  pname = "PkgConfig";
  version = "0.25026";
  src = fetchurl {
    url = "mirror://cpan/authors/id/P/PL/PLICEASE/PkgConfig-0.25026.tar.gz";
    hash = "sha256-Tbpe08LWpoG5XF6/FLammVzmmRrkcZutfxqvOOmHwqA=";
  };
  # support cross-compilation by simplifying the way we get version during build
  postPatch = ''
    substituteInPlace Makefile.PL --replace \
      'do { require "./lib/PkgConfig.pm"; $PkgConfig::VERSION; }' \
      '"${version}"'
  '';
  meta = {
    description = "Pure-Perl Core-Only replacement for pkg-config";
    mainProgram = "ppkg-config";
  };
}

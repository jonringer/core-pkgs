{
  buildPerlPackage,
  fetchurl,
}:

buildPerlPackage {
  pname = "Sort-Versions";
  version = "1.62";
  src = fetchurl {
    url = "mirror://cpan/authors/id/N/NE/NEILB/Sort-Versions-1.62.tar.gz";
    hash = "sha256-v18zB0BuviWBI38CWYLoyE9vZiXdd05FfAP4mU79Lqo=";
  };
  meta = {
    description = "Sorting of revision-like numbers";
  };
}

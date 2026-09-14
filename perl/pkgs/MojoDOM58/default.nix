{
  buildPerlPackage,
  fetchurl,
}:

buildPerlPackage {
  pname = "Mojo-DOM58";
  version = "3.001";
  src = fetchurl {
    url = "mirror://cpan/authors/id/D/DB/DBOOK/Mojo-DOM58-3.001.tar.gz";
    hash = "sha256-GLJtVB5TFEFa3d8xQ2nZQMi6BrESNMpQb9vmzyJPV5Y=";
  };
  meta = {
    description = "Minimalistic HTML/XML DOM parser with CSS selectors";
  };
}

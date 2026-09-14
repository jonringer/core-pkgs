{
  buildPerlPackage,
  fetchurl,
}:

buildPerlPackage {
  pname = "File-chdir";
  version = "0.1011";
  src = fetchurl {
    url = "mirror://cpan/authors/id/D/DA/DAGOLDEN/File-chdir-0.1011.tar.gz";
    hash = "sha256-Mev5Et9I1daB3vdLmIDXix86ykNRoO0f41cLjgOvbHk=";
  };
  meta = {
    description = "More sensible way to change directories";
  };
}

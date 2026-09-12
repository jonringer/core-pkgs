{
  buildPerlPackage,
  fetchurl,
}:

buildPerlPackage {
  pname = "Parse-Yapp";
  version = "1.21";
  src = fetchurl {
    url = "mirror://cpan/authors/id/W/WB/WBRASWELL/Parse-Yapp-1.21.tar.gz";
    hash = "sha256-OBDpmDCPui4PTyYEMDUDKwJ85RzlyKUqi440DKZfE+U=";
  };
  meta = {
    description = "Perl extension for generating and using LALR parsers";
    mainProgram = "yapp";
  };
}

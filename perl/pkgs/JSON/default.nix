{
  buildPerlPackage,
  fetchurl,
}:

buildPerlPackage {
  pname = "JSON";
  version = "4.10";
  src = fetchurl {
    url = "mirror://cpan/authors/id/I/IS/ISHIGAKI/JSON-4.10.tar.gz";
    hash = "sha256-vpB5RkYfhJhKHpAMintoBWnHOFwgJCBYsG2AalPUOyQ=";
  };
  meta = {
    description = "JSON (JavaScript Object Notation) encoder/decoder";
  };
}

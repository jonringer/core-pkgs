{
  buildPerlPackage,
  fetchurl,
}:

buildPerlPackage {
  pname = "Devel-Hide";
  version = "0.0015";
  src = fetchurl {
    url = "mirror://cpan/authors/id/D/DC/DCANTRELL/Devel-Hide-0.0015.tar.gz";
    hash = "sha256-/I2+t/fXWnjtSWseDgXPyZxorKs6LpLP8VXKXw+l31g=";
  };
  meta = {
    description = "Forces the unavailability of specified Perl modules (for testing)";
  };
}

{
  buildPerlPackage,
  fetchurl,
  FileWhich,
  Test2Suite,
}:

buildPerlPackage {
  pname = "FFI-CheckLib";
  version = "0.31";
  src = fetchurl {
    url = "mirror://cpan/authors/id/P/PL/PLICEASE/FFI-CheckLib-0.31.tar.gz";
    hash = "sha256-BNiF/Dd9RIluXqHE7DEPl5uwTy8YZYp+ek1Qn36Au4A=";
  };
  buildInputs = [ Test2Suite ];
  propagatedBuildInputs = [ FileWhich ];
  meta = {
    description = "Check that a library is available for FFI";
  };
}

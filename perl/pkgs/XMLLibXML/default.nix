{
  buildPerlPackage,
  fetchurl,
  lib,
  stdenv,
  libiconv,
  zlib,
  AlienBuild,
  AlienLibxml2,
  XMLSAX,
}:

buildPerlPackage {
  pname = "XML-LibXML";
  version = "2.0213";
  src = fetchurl {
    url = "mirror://cpan/authors/id/T/TO/TODDR/XML-LibXML-2.0213.tar.gz";
    hash = "sha256-KvIcXWGsNOompfq/FbpaWEHmSPcYnbPjO28otUiYAqs=";
  };
  env.SKIP_SAX_INSTALL = 1;
  buildInputs = [
    AlienBuild
    AlienLibxml2
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    libiconv
    zlib
  ];
  propagatedBuildInputs = [ XMLSAX ];
  meta = {
    description = "Perl Binding for libxml2";
  };
}

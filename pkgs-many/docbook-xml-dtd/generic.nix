{
  version,
  src-url,
  src-hash,
  docbook42catalog-url ? null,
  docbook42catalog-hash ? null,
  packageOlder,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  fetchurl,
  unzip,
  findXMLCatalogs,
}@args:

let
  # For DocBook 4.1.2, we need to fetch the catalog from 4.2
  docbook42catalog =
    if docbook42catalog-url != null then
      fetchurl {
        url = docbook42catalog-url;
        hash = docbook42catalog-hash;
      }
    else
      null;
in

stdenv.mkDerivation {
  pname = "docbook-xml";
  inherit version;

  src = fetchurl {
    url = src-url;
    hash = src-hash;
  };

  nativeBuildInputs = [ unzip ];
  propagatedNativeBuildInputs = [ findXMLCatalogs ];

  unpackPhase = ''
    mkdir -p $out/xml/dtd/docbook
    cd $out/xml/dtd/docbook
    unpackFile $src
  '';

  installPhase = ''
    find . -type f -exec chmod -x {} \;
    runHook postInstall
  '';

  postInstall = lib.optionalString (packageOlder "4.2") ''
    sed 's|V4.2|V4.1.2|g' < ${docbook42catalog} > catalog.xml
  '';

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
  };

  meta = {
    description = "DocBook XML document type definitions";
    license = lib.licenses.mit;
    branch = version;
    platforms = lib.platforms.unix;
  };
}

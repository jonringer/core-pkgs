{
  lib,
  buildPythonPackage,
  fetchPypi,
  pythonOlder,
  setuptools,
  setuptools-scm,
  typing-extensions,
  toml,
  zipp,

  # Reverse dependency
  sage,
}:

buildPythonPackage rec {
  pname = "importlib-metadata";
  version = "9.0.1";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchPypi {
    pname = "importlib_metadata";
    inherit version;
    hash = "sha256-q4MFgLwO89thzo+ucWOJ5UYrZ+AzAYurbY+A7xcXL5k=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"coherent.licensed",' ""
  '';

  build-system = [
    setuptools # otherwise cross build fails
    setuptools-scm
  ];

  dependencies = [
    toml
    zipp
  ]
  ++ lib.optionals (pythonOlder "3.8") [ typing-extensions ];

  # Cyclic dependencies due to pyflakefs
  doCheck = false;

  pythonImportsCheck = [ "importlib_metadata" ];

  passthru.tests = {
    inherit sage;
  };

  meta = {
    description = "Read metadata from Python packages";
    homepage = "https://importlib-metadata.readthedocs.io/";
    license = lib.licenses.asl20;

  };
}

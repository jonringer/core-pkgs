{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pythonOlder,

  # build-system
  setuptools,

  # dependencies
  attrs,
  idna,
  outcome,
  sniffio,
  sortedcontainers,
}:

buildPythonPackage rec {
  pname = "trio";
  version = "0.34.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "python-trio";
    repo = "trio";
    tag = "v${version}";
    hash = "sha256-5ooFU1TP9CU0+dpIWs8cw+gHvBzntCnxejpBQn/QffE=";
  };

  build-system = [ setuptools ];

  dependencies = [
    attrs
    idna
    outcome
    sniffio
    sortedcontainers
  ];

  __darwinAllowLocalNetworking = true;

  doCheck = false;

  pythonImportsCheck = [ "trio" ];

  meta = {
    changelog = "https://github.com/python-trio/trio/blob/${src.tag}/docs/source/history.rst";
    description = "Async/await-native I/O library for humans and snake people";
    homepage = "https://github.com/python-trio/trio";
    license = with lib.licenses; [
      mit
      asl20
    ];
  };
}

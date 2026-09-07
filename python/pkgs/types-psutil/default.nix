{
  lib,
  buildPythonPackage,
  fetchPypi,
}:

buildPythonPackage rec {
  pname = "types-psutil";
  version = "7.2.2.20260906";
  format = "wheel";

  src = fetchPypi {
    pname = "types_psutil";
    inherit version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-2wC69/lsP2NCHE09aNNzkjCUoN/d8T6SLFxfvEJIgVk=";
  };

  # Module doesn't have tests
  doCheck = false;

  pythonImportsCheck = [ "psutil-stubs" ];

  meta = {
    description = "Typing stubs for psutil";
    homepage = "https://github.com/python/typeshed";
    license = lib.licenses.asl20;
  };
}

{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  python,
}:

buildPythonPackage rec {
  pname = "lit";
  version = "23.1.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-b9UODKb6xh9KZy6fMBVO3Ks9F8mK64ICrHCbw1P+Mx8=";
  };

  nativeBuildInputs = [ setuptools ];

  passthru = {
    inherit python;
  };

  # Non-standard test suite. Needs custom checkPhase.
  # Needs LLVM's `FileCheck` and `not`: `$out/bin/lit tests`
  # There should be `llvmPackages.lit` since older LLVM versions may
  # have the possibility of not correctly interfacing with newer lit versions
  doCheck = false;

  pythonImportsCheck = [ "lit" ];

  meta = {
    description = "Portable tool for executing LLVM and Clang style test suites";
    mainProgram = "lit";
    homepage = "http://llvm.org/docs/CommandGuide/lit.html";
    license = lib.licenses.ncsa;
  };
}

{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  flit-core,

  # reverse dependencies
  mashumaro ? null,
  pydantic ? null,
}:

buildPythonPackage rec {
  pname = "typing-extensions";
  version = "4.16.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "python";
    repo = "typing_extensions";
    tag = version;
    hash = "sha256-L1BRIDYz0YqYE4geKTxIkbCbzTGz7AtrbpB5vR8T4dw=";
  };

  build-system = [ flit-core ];

  pythonImportsCheck = [ "typing_extensions" ];

  passthru.tests =
    lib.optionalAttrs (mashumaro != null) { inherit mashumaro; }
    // lib.optionalAttrs (pydantic != null) { inherit pydantic; };

  meta = {
    description = "Backported and Experimental Type Hints for Python";
    changelog = "https://github.com/python/typing_extensions/blob/${version}/CHANGELOG.md";
    homepage = "https://github.com/python/typing";
    license = lib.licenses.psfl;
  };
}

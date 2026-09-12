{
  lib,
  buildPythonPackage,
  fetchPypi,
  pythonOlder,

  # build time
  pdm-backend,

  # runtime
  packaging,
  platformdirs,
}:

buildPythonPackage rec {
  pname = "findpython";
  version = "0.8.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-U7MiZIdN+lmQvQnXF4GThtjbMUnYn+IPiP4QeN4oa64=";
  };

  build-system = [ pdm-backend ];

  dependencies = [
    packaging
    platformdirs
  ];

  pythonImportsCheck = [ "findpython" ];

  meta = {
    description = "Utility to find python versions on your system";
    mainProgram = "findpython";
    homepage = "https://github.com/frostming/findpython";
    changelog = "https://github.com/frostming/findpython/releases/tag/${version}";
    license = lib.licenses.mit;

  };
}

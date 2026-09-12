{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  hatch-vcs,
  hatchling,
  pythonOlder,
}:

buildPythonPackage rec {
  pname = "platformdirs";
  version = "4.11.7";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tox-dev";
    repo = "platformdirs";
    tag = version;
    hash = "sha256-qjj3f/D3jJJXIRdtHfUXv9eTpfDZDfv9IxmTImLhFjA=";
  };

  build-system = [
    hatchling
    hatch-vcs
  ];

  pythonImportsCheck = [ "platformdirs" ];

  meta = {
    description = "Module for determining appropriate platform-specific directories";
    homepage = "https://platformdirs.readthedocs.io/";
    changelog = "https://github.com/tox-dev/platformdirs/releases/tag/${src.tag}";
    license = lib.licenses.mit;

  };
}

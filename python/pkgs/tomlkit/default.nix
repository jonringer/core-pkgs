{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build-system
  poetry-core,

  # tests
  pytestCheckHook,
  pyyaml,
}:

buildPythonPackage (finalAttrs: {
  pname = "tomlkit";
  version = "0.15.1";
  pyproject = true;

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-4lu/OIQwBSRiEKEpgndvJ/mcub5nFg4UQ00MDSHuHpc=";
  };

  build-system = [ poetry-core ];

  nativeCheckInputs = [
    pyyaml
    pytestCheckHook
  ];

  testPaths = [ "tests" ];

  pythonImportsCheck = [ "tomlkit" ];

  meta = {
    homepage = "https://github.com/sdispater/tomlkit";
    changelog = "https://github.com/sdispater/tomlkit/blob/${finalAttrs.version}/CHANGELOG.md";
    description = "Style-preserving TOML library for Python";
    license = lib.licenses.mit;
  };
})

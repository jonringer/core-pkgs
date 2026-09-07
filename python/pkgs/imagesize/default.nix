{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
}:

buildPythonPackage rec {
  pname = "imagesize";
  version = "2.0.1";
  pyproject = true;

  build-system = [ setuptools ];

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-srpqTepIen681TJI00dqykSdMNsSot3l4MXKliT9d+U=";
  };

  pythonImportsCheck = [ "imagesize" ];

  meta = {
    description = "Getting image size from png/jpeg/jpeg2000/gif file";
    homepage = "https://github.com/shibukawa/imagesize_py";
    license = with lib.licenses; [ mit ];
  };
}

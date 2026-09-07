{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pytestCheckHook,
  setuptools,
  cython,
  borgbackup ? null,
}:

buildPythonPackage rec {
  pname = "msgpack";
  version = "1.2.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "msgpack";
    repo = "msgpack-python";
    tag = "v${version}";
    hash = "sha256-MMrgG3NudNVvt7xlsn4vUSIEVRGl/BGmXnpus3keGF8=";
  };

  build-system = [ setuptools ];

  nativeBuildInputs = [ cython ];

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [ "msgpack" ];

  passthru.tests = {
    # borgbackup is sensible to msgpack versions: https://github.com/borgbackup/borg/issues/3753
    # please be mindful before bumping versions.
    inherit borgbackup;
  };

  preBuild = ''
    make cython
  '';

  meta = {
    description = "MessagePack serializer implementation";
    homepage = "https://github.com/msgpack/msgpack-python";
    changelog = "https://github.com/msgpack/msgpack-python/blob/${src.tag}/ChangeLog.rst";
    license = lib.licenses.asl20;

  };
}

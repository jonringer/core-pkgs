{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  flit-core,
  pytestCheckHook,
}:

buildPythonPackage (finalAttrs: {
  pname = "idna";
  version = "3.19";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "kjd";
    repo = "idna";
    tag = "v${finalAttrs.version}";
    hash = "sha256-94qiHConTqLRjXZ2DcmCiQ2mhOvmizytRB1+YhGoaAo=";
  };

  build-system = [ flit-core ];

  pythonImportsCheck = [ "idna" ];

  nativeCheckInputs = [ pytestCheckHook ];

  testPaths = [ "tests" ];

  meta = {
    homepage = "https://github.com/kjd/idna/";
    changelog = "https://github.com/kjd/idna/releases/tag/${finalAttrs.src.tag}";
    description = "Internationalized Domain Names in Applications (IDNA)";
    license = lib.licenses.bsd3;

  };
})

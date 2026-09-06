{
  lib,
  stdenv,
  aiohttp,
  buildPythonPackage,
  fetchFromGitHub,
  isPyPy,
  mypy,
  pytestCheckHook,
  requests,
  setuptools,
  setuptools-scm,
  # mypyc compilation needs a working mypy for the host; it is also the leg of
  # the cycle rustPlatform.fetchCargoVendor breaks when it builds its own
  # requests, so keep it switchable.
  withMypyc ? !isPyPy && !stdenv.hostPlatform.isStatic,
}:

buildPythonPackage rec {
  pname = "charset-normalizer";
  version = "3.5.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jawah";
    repo = "charset_normalizer";
    tag = version;
    hash = "sha256-zIN1y9HVwaCqixjRFLn6g/tz95E41m7t7j4eY5jNZMs=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ]
  ++ lib.optional withMypyc mypy;

  env.CHARSET_NORMALIZER_USE_MYPYC = lib.optionalString withMypyc "1";

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [ "charset_normalizer" ];

  passthru.tests = {
    inherit aiohttp requests;
  };

  meta = {
    description = "Python module for encoding and language detection";
    mainProgram = "normalizer";
    homepage = "https://charset-normalizer.readthedocs.io/";
    changelog = "https://github.com/jawah/charset_normalizer/blob/${src.tag}/CHANGELOG.md";
    license = lib.licenses.mit;

  };
}

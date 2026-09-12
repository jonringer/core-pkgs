{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pythonOlder,

  # build-system
  hatch-vcs,
  hatchling,
  cmake,
  ninja,

  # dependencies
  packaging,
  pathspec,
  exceptiongroup,
  tomli,
}:

buildPythonPackage (finalAttrs: {
  pname = "scikit-build-core";
  version = "1.0.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "scikit-build";
    repo = "scikit-build-core";
    tag = "v${finalAttrs.version}";
    hash = "sha256-pEBdDXmg9wSrOBRTiUrVqdAcN5WEdHPIcGhpm3ze130=";
  };

  postPatch = lib.optionalString (pythonOlder "3.11") ''
    substituteInPlace pyproject.toml \
      --replace-fail '"error",' '"error", "ignore::UserWarning",'
  '';

  build-system = [
    hatch-vcs
    hatchling
  ];

  dependencies = [
    packaging
    pathspec
  ]
  ++ lib.optionals (pythonOlder "3.11") [
    exceptiongroup
    tomli
  ];

  # Tests are expensive and creates issues with cyclic dependencies
  # nativeCheckInputs = [
  #   build
  #   cattrs
  #   cmake
  #   ninja
  #   numpy
  #   pybind11
  #   pytest-subprocess
  #   pytestCheckHook
  #   setuptools
  #   virtualenv
  #   wheel
  # ];

  setupHooks = [
    ./append-cmakeFlags.sh
  ];

  disabledTestMarks = [
    "isolated"
    "network"
  ];

  testPaths = [ "tests" ];

  disabledTestPaths = [
    # store permissions issue in Nix:
    "tests/test_editable.py"
  ];

  pythonImportsCheck = [ "scikit_build_core" ];

  meta = {
    description = "Next generation Python CMake adaptor and Python API for plugins";
    homepage = "https://github.com/scikit-build/scikit-build-core";
    changelog = "https://github.com/scikit-build/scikit-build-core/blob/${finalAttrs.src.tag}/docs/about/changelog.md";
    license = with lib.licenses; [ asl20 ];

  };
})

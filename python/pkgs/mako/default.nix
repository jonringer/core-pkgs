{
  lib,
  buildPythonPackage,
  pythonOlder,
  fetchFromGitHub,
  isPyPy,

  # build-system
  setuptools,

  # propagates
  markupsafe,

  # optional-dependencies
  babel ? null,
  lingua ? null,

  # tests
  mock,
  pytestCheckHook,
}:

buildPythonPackage (finalAttrs: {
  pname = "mako";
  version = "1.3.10";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "sqlalchemy";
    repo = "mako";
    tag = "rel_${lib.replaceStrings [ "." ] [ "_" ] finalAttrs.version}";
    hash = "sha256-lxGlYyKbrDpr2LHcsqTow+s2l8+g+63M5j8xJt++tGo=";
  };

  build-system = [ setuptools ];

  dependencies = [ markupsafe ];

  optional-dependencies = {
    babel = lib.optional (babel != null) babel;
    lingua = lib.optional (lingua != null) lingua;
  };

  nativeCheckInputs = [
    mock
    pytestCheckHook
  ]
  ++ lib.concatAttrValues finalAttrs.optional-dependencies;

  testPaths = [ "test" ];

  disabledTests = lib.optionals isPyPy [
    # https://github.com/sqlalchemy/mako/issues/315
    "test_alternating_file_names"
    # https://github.com/sqlalchemy/mako/issues/238
    "test_file_success"
    "test_stdin_success"
    # fails on pypy2.7
    "test_bytestring_passthru"
  ];

  pythonImportsCheck = [ "mako" ];

  meta = {
    description = "Super-fast templating language";
    mainProgram = "mako-render";
    homepage = "https://www.makotemplates.org/";
    changelog = "https://docs.makotemplates.org/en/latest/changelog.html";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;

  };
})

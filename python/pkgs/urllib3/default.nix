{
  lib,
  buildPythonPackage,
  fetchPypi,
  isPyPy,

  # build-system
  hatchling,
  hatch-vcs,

  # optional-dependencies
  brotli,
  brotlicffi,
  pysocks,
  zstandard,

  # tests
  pytestCheckHook,
  pytest-timeout,
  tornado ? null,
  trustme ? null,
}:

let
  self = buildPythonPackage rec {
    pname = "urllib3";
    version = "2.7.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-Ix4Ow7Y86xRmfGe+YPLyxApRjLOLA69gq8gT2iZQX0w=";
    };

    build-system = [
      hatchling
      hatch-vcs
    ];

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail ', "setuptools-scm>=8,<11"' ""
    '';

    optional-dependencies = {
      brotli = if isPyPy then [ brotlicffi ] else [ brotli ];
      socks = [ pysocks ];
      zstd = [ zstandard ];
    };

    nativeCheckInputs = [
      pytest-timeout
      pytestCheckHook
    ]
    ++ lib.optional (tornado != null) tornado
    ++ lib.optional (trustme != null) trustme
    ++ lib.concatAttrValues optional-dependencies;

    # Tests in urllib3 are mostly timeout-based instead of event-based and
    # are therefore inherently flaky. On your own machine, the tests will
    # typically build fine, but on a loaded cluster such as Hydra random
    # timeouts will occur.
    #
    # The urllib3 test suite has two different timeouts in their test suite
    # (see `test/__init__.py`):
    # - SHORT_TIMEOUT
    # - LONG_TIMEOUT
    # When CI is in the env, LONG_TIMEOUT will be significantly increased.
    # Still, failures can occur and for that reason tests are disabled.
    doCheck = false;

    passthru.tests.pytest = self.overridePythonAttrs (_: {
      doCheck = true;
    });

    preCheck = ''
      export CI # Increases LONG_TIMEOUT
    '';

    pythonImportsCheck = [ "urllib3" ];

    meta = {
      description = "Powerful, user-friendly HTTP client for Python";
      homepage = "https://github.com/urllib3/urllib3";
      changelog = "https://github.com/urllib3/urllib3/blob/${version}/CHANGES.rst";
      license = lib.licenses.mit;
    };
  };
in
self

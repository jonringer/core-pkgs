{
  lib,
  stdenv,
  buildPythonPackage,
  pythonOlder,
  fetchPypi,
  flit-core,
  babel ? null,
  markupsafe,
  pytestCheckHook,

  # Reverse dependency
  sage ? null,
}:

buildPythonPackage rec {
  pname = "jinja2";
  version = "3.1.6";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ATf7BZkNNfEnWlh+mu5tVtqCH8g0kaD7g4GDvkP2bW0=";
  };

  postPatch = ''
    # Do not test with trio, it increases jinja2's dependency closure by a lot
    # and everyone consuming these dependencies cannot rely on sphinxHook,
    # because sphinx itself depends on jinja2.
    substituteInPlace tests/test_async{,_filters}.py \
      --replace-fail "import trio" "" \
      --replace-fail ", trio.run" "" \
      --replace-fail ", \"trio\"" ""
  '';

  build-system = [ flit-core ];

  dependencies = [ markupsafe ];

  optional-dependencies = {
    i18n = lib.optional (babel != null) babel;
  };

  # Multiple tests run out of stack space on 32bit systems with python2.
  # See https://github.com/pallets/jinja/issues/1158
  doCheck = !stdenv.hostPlatform.is32bit;

  nativeCheckInputs = [ pytestCheckHook ] ++ optional-dependencies.i18n;

  passthru.tests = { } // lib.optionalAttrs (sage != null) { inherit sage; };

  pythonImportsCheck = [ "jinja2" ];

  meta = {
    changelog = "https://github.com/pallets/jinja/blob/${version}/CHANGES.rst";
    description = "Very fast and expressive template engine";
    downloadPage = "https://github.com/pallets/jinja";
    homepage = "https://jinja.palletsprojects.com";
    license = lib.licenses.bsd3;
    longDescription = ''
      Jinja is a fast, expressive, extensible templating engine. Special
      placeholders in the template allow writing code similar to Python
      syntax. Then the template is passed data to render the final document.
    '';

  };
}

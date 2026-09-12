{
  lib,
  betamax,
  buildPythonPackage,
  fetchPypi,
  pyopenssl,
  pytestCheckHook,
  requests,
  trustme ? null,
}:

buildPythonPackage (finalAttrs: {
  pname = "requests-toolbelt";
  version = "1.0.0";
  format = "setuptools";

  src = fetchPypi {
    pname = "requests-toolbelt";
    inherit (finalAttrs) version;
    hash = "sha256-doGgo9BHAStb3A7jfX+PB+vnarCMrsz8OSHOI8iNW8Y=";
  };

  propagatedBuildInputs = [ requests ];

  doCheck = false;
  nativeCheckInputs = [
    betamax
    pyopenssl
    pytestCheckHook
  ]
  ++ lib.optional (trustme != null) trustme;

  disabledTests = [
    # incompatible with urllib3 2.0
    "test_dump_response"
    "test_dump_all"
    "test_prepared_request_override_base"
    "test_prepared_request_with_base"
    "test_request_override_base"
    "test_request_with_base"
  ];

  pythonImportsCheck = [ "requests_toolbelt" ];

  passthru.tests = {
    unitTests = finalAttrs.finalPackage.overridePythonAttrs { doCheck = true; };
  };

  meta = {
    description = "Toolbelt of useful classes and functions to be used with requests";
    homepage = "http://toolbelt.rtfd.org";
    changelog = "https://github.com/requests/toolbelt/blob/${finalAttrs.version}/HISTORY.rst";
    license = lib.licenses.asl20;
  };
})

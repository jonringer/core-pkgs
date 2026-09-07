{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  hatchling,
  pytest-cov-stub ? null,
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "wcwidth";
  version = "0.8.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jquast";
    repo = "wcwidth";
    tag = version;
    hash = "sha256-4GzYqoXdYqZjyB/iIsuOnwSjJGSKY9LitVKVDT2aUCo=";
  };

  build-system = [ hatchling ];

  doCheck = false;

  nativeCheckInputs = [
    pytest-cov-stub
    pytestCheckHook
  ];

  pythonImportsCheck = [ "wcwidth" ];

  meta = {
    description = "Measures number of Terminal column cells of wide-character codes";
    longDescription = ''
      This API is mainly for Terminal Emulator implementors -- any Python
      program that attempts to determine the printable width of a string on
      a Terminal. It is implemented in python (no C library calls) and has
      no 3rd-party dependencies.
    '';
    homepage = "https://github.com/jquast/wcwidth";
    changelog = "https://github.com/jquast/wcwidth/releases/tag/${src.tag}";
    license = lib.licenses.mit;
  };
}

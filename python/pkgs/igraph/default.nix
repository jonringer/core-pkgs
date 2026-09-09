{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pkg-config,
  cmake,
  setuptools,
  pkgs,
  texttable,
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "igraph";
  version = "1.0.0";

  pyproject = true;

  src = fetchFromGitHub {
    owner = "igraph";
    repo = "python-igraph";
    tag = version;
    postFetch = ''
      # export-subst prevents reproducability
      rm $out/.git_archival.json
    '';
    hash = "sha256-Y7ZQ1yNoD8A5b6c92OGz9Unietdg1uNt/Za6nxdCSP0=";
  };

  postPatch = ''
    rm -r vendor
  '';

  nativeBuildInputs = [
    pkg-config
    cmake
  ];

  build-system = [ setuptools ];

  buildInputs = [ pkgs.igraph ];

  dependencies = [ texttable ];

  # NB: We want to use our igraph, not vendored igraph, but even with
  # pkg-config on the PATH, their custom setup.py still needs to be explicitly
  # told to do it. ~ C.
  env.IGRAPH_USE_PKG_CONFIG = true;

  nativeCheckInputs = [ pytestCheckHook ];

  disabledTests = [
    "testAuthorityScore"
    "test_labels"
  ];

  testPaths = [ "tests" ];

  pythonImportsCheck = [ "igraph" ];

  meta = {
    description = "High performance graph data structures and algorithms";
    mainProgram = "igraph";
    homepage = "https://igraph.org/python/";
    license = lib.licenses.gpl2Plus;
  };
}

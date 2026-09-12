{
  stdenv,
  file,
  lib,
  fetchFromGitHub,
  autoreconfHook,
  bison,
  flex,
  pkg-config,
  doxygen,
  graphviz,
  mscgen ? null,
  asciidoc,
  sourceHighlight,
  libpcap,
  pythonSupport ? false,
  swig,
  python,
}:

stdenv.mkDerivation rec {
  pname = "libnl";
  version = "3.11.0";

  src = fetchFromGitHub {
    repo = "libnl";
    owner = "thom311";
    rev = "libnl${lib.replaceStrings [ "." ] [ "_" ] version}";
    hash = "sha256-GuYV2bUOhLedB/o9Rz6Py/G5HBK2iNefwrlkZJXgbnI=";
  };

  outputs = [
    "bin"
    "dev"
    "out"
    "man"
  ]
  ++ lib.optional pythonSupport "py";

  nativeBuildInputs = [
    autoreconfHook
    bison
    flex
    pkg-config
    file
    doxygen
    graphviz
  ]
  ++ lib.optional (mscgen != null) mscgen
  ++ [
    asciidoc
    sourceHighlight
  ]
  ++ lib.optional pythonSupport swig;

  postBuild = lib.optionalString pythonSupport ''
    cd python
    ${python.pythonOnBuildForHost.interpreter} setup.py install --prefix=../pythonlib
    cd -
  '';

  postFixup = lib.optionalString pythonSupport ''
    mv "pythonlib/" "$py"
  '';

  passthru = {
    inherit pythonSupport;
    tests = {
      inherit libpcap;
    };
  };

  meta = {
    homepage = "http://www.infradead.org/~tgr/libnl/";
    description = "Linux Netlink interface library suite";
    license = lib.licenses.lgpl21;
    platforms = lib.platforms.linux;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "infradead" version;
  };
}

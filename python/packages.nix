final: prev: with final; {

  libxml2 = (toPythonModule (pkgs.libxml2.override {
    pythonSupport = true;
    inherit python3;
  })).py;

  libxslt = (toPythonModule (pkgs.libxslt.override {
    pythonSupport = true;
    inherit (self) python3 libxml2;
  })).py;

}

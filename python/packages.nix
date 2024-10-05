final: prev: with final; {

  # bootstrap is located outside of pkgs/ to avoid the hook trying to call the directory
  bootstrap = lib.recurseIntoAttrs {
    flit-core = toPythonModule (callPackage ./bootstrap/flit-core { });
    installer = toPythonModule (callPackage ./bootstrap/installer {
      inherit (bootstrap) flit-core;
    });
    build = toPythonModule (callPackage ./bootstrap/build {
      inherit (bootstrap) flit-core installer;
    });
    packaging = toPythonModule (callPackage ./bootstrap/packaging {
      inherit (bootstrap) flit-core installer;
    });
  };


  libxml2 = (toPythonModule (pkgs.libxml2.override {
    pythonSupport = true;
    inherit python3;
  })).py;

  libxslt = (toPythonModule (pkgs.libxslt.override {
    pythonSupport = true;
    inherit (final) python libxml2;
  })).py;

  lxml = prev.lxml.override {
    inherit (pkgs) libxml2 libxslt;
  };

}

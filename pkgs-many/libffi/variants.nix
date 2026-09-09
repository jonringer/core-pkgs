{
  real = {
    implementation = "upstream";
    version = "3.6.0";
    hash = "sha256-Mf8f4y3q6/uziHJ/Mmd7slS/KkE4LFFGTAsYN8numCg=";
  };
  darwin = {
    implementation = "darwin";
    version =
      (builtins.fromJSON (builtins.readFile ../../pkgs/sourceRelease/versions.json)).libffi.version;
  };
}

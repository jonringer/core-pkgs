{ lib
, versions
}:

{
  # Compatibility with upstream nixpkgs
  v3 = versions.v3_0;
  v1_0 = throw "Openssl 1.0.x is EOL, and no longer supported";
}

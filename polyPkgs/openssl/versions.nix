# intended version "policy":
# - 1.1 as long as some package exists, which does not build without it
#   (tracking issue: https://github.com/NixOS/nixpkgs/issues/269713)
#   try to remove in 24.05 for the first time, if possible then
# - latest 3.x LTS
# - latest 3.x non-LTS as preview/for development
#
# - other versions in between only when reasonable need is stated for some package
# - backport every security critical fix release e.g. 3.0.y -> 3.0.y+1 but no new version, e.g. 3.1 -> 3.2

# If you do upgrade here, please update in release.nix
# the permitted insecure version to ensure it gets cached for our users
# and backport this to stable release (at time of writing this 23.11).

{
  v1_1 = {
    version = "1.1.1w";
    hash = "sha256-zzCYlQy02FOtlcCEHx+cbT3BAtzPys1SHZOSUgi3asg=";
  };

  v3_0 = {
    version = "3.0.14";
    hash = "sha256-7soDXU3U6E/CWEbZUtpil0hK+gZQpvhMaC453zpBI8o=";
  };

  v3_2 = {
    version = "3.2.2";
    hash = "sha256-GXFJwY2enyksQ/BACsq6EuX1LKz+BQ89GZJ36nOOwuc=";
  };

  v3_3 = {
    version = "3.3.1";
    hash = "sha256-d3zVlihMiDN1oqehG/XSeG/FQTJV76sgxQ1v/m0CC34=";
  };
}

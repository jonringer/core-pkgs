{ makeSetupHook, dieHook }:

makeSetupHook {
  name = "shorten-perl-shebang-hook";
  propagatedBuildInputs = [ dieHook ];
} ./shorten-perl-shebang.sh

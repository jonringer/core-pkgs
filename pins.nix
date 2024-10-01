{
  stdenvRepo = builtins.fetchGit {
    url = "https://github.com/jonringer/stdenv.git";
    rev = "a80f322f206206e1bab1cf76eb7dad1351e57aa1";
  };

  lib = import (builtins.fetchGit {
    url = "https://github.com/jonringer/nix-lib.git";
    rev = "c19c816e39d14a60dd368d601aa9b389b09d0bbb";
  });
}


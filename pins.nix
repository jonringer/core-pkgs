{
  stdenvRepo = builtins.fetchGit {
    url = "https://github.com/jonringer/stdenv.git";
    rev = "8593af2030421f4668b7aefe38c9aecf63c6effa";
  };

  lib = import (builtins.fetchGit {
    url = "https://github.com/jonringer/nix-lib.git";
    rev = "c19c816e39d14a60dd368d601aa9b389b09d0bbb";
  });
}


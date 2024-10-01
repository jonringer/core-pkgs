{
  #stdenvRepo = builtins.fetchGit {
  #  url = "https://github.com/jonringer/stdenv.git";
  #  rev = "baa4b77ac334345ba243e6618a137b35a259efd5";
  #};
  stdenvRepo = ../stdenv;

  lib = import (builtins.fetchGit {
    url = "https://github.com/jonringer/nix-lib.git";
    rev = "c19c816e39d14a60dd368d601aa9b389b09d0bbb";
  });
}


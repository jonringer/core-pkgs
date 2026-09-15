{
  lib,
  fetchFromGitHub,
  llvmPackages_21,
  libblake3,
  zstd,
  nlohmann_json,
}:

let
  clangStdenv = llvmPackages_21.libcxxStdenv;
in

clangStdenv.mkDerivation (finalAttrs: {
  pname = "jig";
  version = "0-unstable-2026-09-10";

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "repkgs";
    rev = "1cd7b8b03526f35d45dc66c94c1e1b63d0e636ca";
    hash = "sha256-5Z94QJiwg9PqVHlMSHJ/yqk36WpJD9RL2JmfgBBtRsA=";
  };

  sourceRoot = "${finalAttrs.src.name}/pkgs/ji/jig";

  buildInputs = [
    libblake3
    zstd
  ];

  # jig does #include <json.hpp> but our nlohmann_json has split headers;
  # patch the include and add the standard include path
  postPatch = ''
    substituteInPlace src/nix_store_mode.cc \
      --replace-fail '#include <json.hpp>' '#include <nlohmann/json.hpp>'
  '';

  env.NIX_CFLAGS_COMPILE = "-isystem ${nlohmann_json.include}/include";

  makeFlags = [
    "CXX=${clangStdenv.cc.targetPrefix}clang++"
    "CXXFLAGS=-std=c++26 -O2 -Wall -Wextra -Werror -Wno-unused-command-line-argument -U_LIBCPP_HARDENING_MODE -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE -fno-exceptions -DJIG_STORE_DIR='\"${builtins.storeDir}\"'"
    "NIX_STORE_DIR=${builtins.storeDir}"
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp build/jig $out/bin/jig
    runHook postInstall
  '';

  meta = {
    description = "Content-addressed compilation cache and compiler driver";
    homepage = "https://github.com/Mic92/repkgs";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "jig";
  };
})

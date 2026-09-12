# solc — Solidity compiler for Ethereum smart contracts
{
  lib,
  stdenv,
  fetchzip,
  boost,
  cmake,
}:

stdenv.mkDerivation rec {
  pname = "solc";
  version = "0.8.36";

  src = fetchzip {
    url = "https://github.com/ethereum/solidity/releases/download/v${version}/solidity_${version}.tar.gz";
    hash = "sha256-qIChFkTTmHklgj06fYvn6Ghi9ZW4rlyY/lvfMWxyVlk=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
  ];
  buildInputs = [ boost ];

  cmakeFlags = [
    "-DBoost_USE_STATIC_LIBS=OFF"
    "-DUSE_Z3=OFF"
    "-DUSE_CVC4=OFF"
  ];

  meta = {
    description = "Compiler for Ethereum smart contract language Solidity";
    homepage = "https://github.com/ethereum/solidity";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
  };
}

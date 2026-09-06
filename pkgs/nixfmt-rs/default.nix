{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "nixfmt-rs";
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = pname;
    rev = version;
    sha256 = "sha256-ELXgj/ij6m5aipXVb7vdzD/+77YHTyytVv900Bcp1yU=";
  };

  cargoHash = "sha256-LVn9QxJU2r6urD6MA7Z52ajXcgE2Q6dmjirgA/jBKUw=";

  doCheck = false;

  meta = with lib; {
    description = "A from-scratch Rust reimplementation of nixfmt that produces byte-identical output to the Haskell original.";
    homepage = "https://github.com/Mic92/nixfmt-rs";
    license = licenses.mpl20;
    mainProgram = "nixfmt";
  };
}

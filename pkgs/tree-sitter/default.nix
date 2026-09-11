{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  which,
  installShellFiles,
  buildPackages,
  enableShared ? !stdenv.hostPlatform.isStatic,
  enableStatic ? stdenv.hostPlatform.isStatic,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tree-sitter";
  version = "0.26.9";

  src = fetchFromGitHub {
    owner = "tree-sitter";
    repo = "tree-sitter";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ohVhW4AEKX5VspqBePtfxbJGkjmJnNkf5ntU3RUxF+0=";
    fetchSubmodules = true;
  };

  cargoHash = "sha256-3egxdusYHQs8PadxGZ44+VWtlTcGBrcqlWMUyUzpWnY=";

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    which
  ];

  buildInputs = [
    installShellFiles
  ];

  # Tests require grammar fixtures not included in the source
  doCheck = false;

  patches = [
    ./remove-web-interface.patch
  ];

  postPatch = lib.optionalString stdenv.hostPlatform.isStatic ''
    substituteInPlace ./Makefile \
        --replace-fail 'all: libtree-sitter.a libtree-sitter.$(SOEXT) tree-sitter.pc' 'all: libtree-sitter.a tree-sitter.pc'
    sed -i '/^install:/,/^[^[:space:]]/ { /$(SOEXT/d; }' ./Makefile
  '';

  postInstall = ''
    PREFIX=$out make install
    ${lib.optionalString (!enableShared) "rm -f $out/lib/*.so{,.*}"}
    ${lib.optionalString (!enableStatic) "rm -f $out/lib/*.a"}
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd tree-sitter \
      --bash <("$out/bin/tree-sitter" complete --shell bash) \
      --zsh <("$out/bin/tree-sitter" complete --shell zsh) \
      --fish <("$out/bin/tree-sitter" complete --shell fish)
  '';

  meta = {
    homepage = "https://github.com/tree-sitter/tree-sitter";
    description = "Parser generator tool and an incremental parsing library";
    mainProgram = "tree-sitter";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})

{
  version,
  src-hash,
  cargo-hash,
  librusty-v8-version,
  librusty-v8-hashes,
  build-features,
  packageAtLeast,
  packageOlder,
  ...
}:

{
  stdenv,
  lib,
  callPackage,
  fetchFromGitHub,
  rustPlatform,
  cmake,
  yq-go,
  protobuf,
  installShellFiles,
  makeBinaryWrapper,
  libffi,
  sqlite,
  lld,
  writableTmpDirAsHomeHook,
  fetchurl,

  # Test deps
  curl,
  nodejs,
  git,
  python3,
  esbuild,
}:

let
  fetchLibrustyV8 = callPackage ./fetchers.nix { };
  librusty_v8 = fetchLibrustyV8.fetchLibrustyV8 {
    version = librusty-v8-version;
    shas = librusty-v8-hashes;
  };
  canExecute = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
in
rustPlatform.buildRustPackage {
  pname = "deno";
  inherit version;

  src = fetchFromGitHub {
    owner = "denoland";
    repo = "deno";
    tag = "v${version}";
    fetchSubmodules = true;
    hash = src-hash;
  };

  cargoHash = cargo-hash;

  patches = [
    ./patches/0002-tests-replace-hardcoded-paths.patch
    ./patches/0003-tests-linux-no-chown.patch
    ./patches/0004-tests-darwin-fixes.patch
  ];
  postPatch = ''
    # Use patched nixpkgs libffi in order to fix https://github.com/libffi/libffi/pull/857
    yq --inplace --input-format toml --output-format toml \
      '.workspace.dependencies.libffi = { "version": .workspace.dependencies.libffi, "features": ["system"] }' \
      Cargo.toml
  '';

  buildInputs = [
    libffi
    sqlite
  ];

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    yq-go
    cmake
    protobuf
    installShellFiles
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ lld ];

  configureFlags = lib.optionals stdenv.cc.isClang [
    "--disable-multi-os-directory"
  ];

  buildFlags = [ "--package=cli" ];

  buildNoDefaultFeatures = true;
  buildFeatures = build-features;

  env.NIX_CFLAGS_COMPILE = lib.optionalString stdenv.cc.isClang "-Wno-unknown-warning-option";
  env.RUSTY_V8_ARCHIVE = librusty_v8;

  doCheck =
    stdenv.hostPlatform.isDarwin
    || (stdenv.hostPlatform.isLinux && (stdenv.hostPlatform.isAarch64 || stdenv.hostPlatform.isx86_64));

  preCheck =
    let
      platform =
        if stdenv.hostPlatform.isLinux then
          "linux64"
        else if stdenv.hostPlatform.isDarwin then
          "mac"
        else
          throw "Unsupported platform";
      arch =
        if stdenv.hostPlatform.isAarch64 then
          "aarch64"
        else if stdenv.hostPlatform.isx86_64 then
          "x64"
        else
          throw "Unsupported architecture";
    in
    ''
      mkdir -p ./third_party/prebuilt/${platform}
      cp ${lib.getExe esbuild} ./third_party/prebuilt/${platform}/esbuild-${arch}
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      unset LD_DYLD_PATH
    '';

  cargoTestFlags = [
    "--lib"
    "--test=integration_test"
  ];
  checkFlags = [
    "--skip=check::ts_no_recheck_on_redirect"
    "--skip=js_unit_tests::quic_test"
    "--skip=js_unit_tests::net_test"
    "--skip=node_unit_tests::http_test"
    "--skip=node_unit_tests::http2_test"
    "--skip=node_unit_tests::net_test"
    "--skip=node_unit_tests::tls_test"
    "--skip=npm::lock_file_lock_write"
    "--skip=js_unit_tests::webgpu_test"
    "--skip=js_unit_tests::jupyter_test"
    "--skip=specs::permission::proc_self_fd"
    "--skip=init::init_subcommand_serve"
    "--skip=serve::deno_serve_parallel"
    "--skip=js_unit_tests::stat_test"
    "--skip=repl::pty_complete_imports"
    "--skip=repl::pty_complete_expression"
    "--skip=repl::pty_complete_imports_no_panic_empty_specifier"
    "--skip=js_unit_tests::serve_test"
    "--skip=js_unit_tests::fetch_test"
    "--skip=upgrade::upgrade_prompt"
    "--skip=upgrade::upgrade_invalid_lockfile"
    "--skip=node_unit_tests::process_test"
    "--skip=sqlite_extension_test"
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    "--skip=shared_library_tests::macos_shared_libraries"
    "--skip=watcher"
    "--skip=node_unit_tests::_fs_watch_test"
    "--skip=js_unit_tests::fs_events_test"
    "--skip=js_unit_tests::utime_test"
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    "--skip=tests::test_userspace_resolver"
  ];

  __darwinAllowLocalNetworking = true;

  nativeCheckInputs = [
    writableTmpDirAsHomeHook
    curl
    nodejs
    git
    python3
  ];

  preInstall = ''
    find ./target \
      -name "libswc_common${stdenv.hostPlatform.extensions.sharedLibrary}" -o \
      -name "libtest_ffi${stdenv.hostPlatform.extensions.sharedLibrary}" -o \
      -name "libtest_napi${stdenv.hostPlatform.extensions.sharedLibrary}" \
      -delete
  '';

  postInstall = ''
    find $out/bin/* -not -name "deno" -delete
    makeBinaryWrapper $out/bin/deno $out/bin/dx --add-flags "x"
  ''
  + lib.optionalString canExecute ''
    installShellCompletion --cmd deno \
      --bash <($out/bin/deno completions bash) \
      --fish <($out/bin/deno completions fish) \
      --zsh <($out/bin/deno completions zsh)
  '';

  doInstallCheck = canExecute;
  installCheckPhase = lib.optionalString canExecute ''
    runHook preInstallCheck
    $out/bin/deno --help
    $out/bin/deno --version | grep "deno ${version}"
    runHook postInstallCheck
  '';

  passthru = {
    updateScript = ./update/update.ts;
    tests = callPackage ./tests { };
    inherit librusty_v8;
  };

  meta = {
    homepage = "https://deno.land/";
    changelog = "https://github.com/denoland/deno/releases/tag/v${version}";
    description = "Secure runtime for JavaScript and TypeScript";
    license = lib.licenses.mit;
    mainProgram = "deno";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "deno" version;
  };
}

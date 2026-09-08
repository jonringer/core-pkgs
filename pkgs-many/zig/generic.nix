{
  version,
  src-url,
  src-hash,
  llvm-major,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  cmake,
  ninja,
  zlib,
  libxml2,
  coreutils,
  callPackage,
  llvm,
}:

let
  llvmPkgs = llvm.${"v" + llvm-major}.pkgs;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "zig";
  inherit version;

  src = fetchurl {
    url = src-url;
    hash = src-hash;
  };

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    llvmPkgs.llvm
    llvmPkgs.lld
    llvmPkgs.libclang
    zlib
    libxml2
  ];

  cmakeFlags = [
    "-DCMAKE_SKIP_BUILD_RPATH=ON"
    "-DZIG_STATIC_LLVM=ON"
    "-DZIG_TARGET_MCPU=baseline"
  ];

  configurePhase = "cmakeConfigurePhase";
  buildPhase = "ninjaBuildPhase";

  doCheck = false;

  # Zig inspects /usr/bin/env as an ELF binary to detect the host dynamic
  # linker and glibc version.  In Nix's sandbox /usr/bin/env either doesn't
  # exist or doesn't carry the right info, so zig falls back to musl.
  # Point it at the coreutils env binary instead.
  postPatch = ''
    substituteInPlace lib/std/zig/system.zig \
      --replace-fail "/usr/bin/env" "${lib.getExe' coreutils "env"}"
  '';

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-cache"
  '';

  # Safety net: ensure the final binary uses the nix glibc interpreter.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/zig
  '';

  postInstall = ''
    ln -s $out/bin/zig $out/bin/zig-${lib.versions.majorMinor version} || true
  '';

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
    hook = callPackage ./setup-hook.nix { zig = finalAttrs.finalPackage; };
  };

  meta = {
    description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
    homepage = "https://ziglang.org/";
    changelog = "https://ziglang.org/download/${version}/release-notes.html";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "zig";
  };
})

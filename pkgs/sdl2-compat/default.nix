{
  cmake,
  lib,
  fetchFromGitHub,
  ninja,
  sdl3,
  stdenv,
  testers,
  libx11,
  libGL,
  nix-update-script,

  x11Support ? !stdenv.hostPlatform.isAndroid && !stdenv.hostPlatform.isWindows,
}:
let
  # sdl2 has no tray API, so drop the requirement rather than carry whatever
  # sdl3's tray backend pulls in.
  sdl3' = sdl3.override { traySupport = false; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "sdl2-compat";
  version = "2.32.72";

  src = fetchFromGitHub {
    owner = "libsdl-org";
    repo = "sdl2-compat";
    tag = "release-${finalAttrs.version}";
    hash = "sha256-JuIJbOs+hvkPev/WQobnrsXOvD6eF5V8qpb/vh/LDPk=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
    ninja
  ];

  buildInputs = [
    sdl3'
  ]
  ++ lib.optional x11Support libx11;

  checkInputs = [ libGL ];

  outputs = [
    "out"
    "dev"
  ];

  outputBin = "dev";

  # SDL3 is dlopened at runtime, leave it in runpath
  dontPatchELF = true;

  cmakeFlags = [
    (lib.cmakeBool "SDL2COMPAT_TESTS" finalAttrs.finalPackage.doCheck)
    (lib.cmakeFeature "CMAKE_INSTALL_RPATH" (lib.makeLibraryPath [ sdl3' ]))
    (lib.cmakeFeature "CMAKE_BUILD_RPATH" (lib.makeLibraryPath [ sdl3' ]))
  ];

  # skip timing-based tests as those are flaky
  env.SDL_TESTS_QUICK = 1;

  doCheck = true;

  patches = [
    ./find-headers.patch
  ];
  setupHook = ./setup-hook.sh;

  postFixup = ''
    # allow as a drop in replacement for SDL2
    ln -s $dev/lib/pkgconfig/sdl2-compat.pc $dev/lib/pkgconfig/sdl2.pc
  '';

  passthru = {
    tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;

    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex"
        "release-(.*)"
      ];
    };
  };

  meta = {
    description = "SDL2 compatibility layer that uses SDL3 behind the scenes";
    homepage = "https://libsdl.org";
    changelog = "https://github.com/libsdl-org/sdl2-compat/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.zlib;
    platforms = lib.platforms.all;
    pkgConfigModules = [
      "sdl2-compat"
      "sdl2"
    ];
  };
})

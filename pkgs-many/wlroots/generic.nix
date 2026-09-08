{
  version,
  src-hash,
  packageAtLeast,
  packageOlder,
  mkVariantPassthru,
  ...
}:

{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  wayland-scanner,
  libGL,
  wayland,
  wayland-protocols,
  libinput,
  libxkbcommon,
  pixman,
  libcap,
  libgbm,
  xcbutilwm,
  xcbutilrenderutil,
  xcbutilimage,
  xcbutilerrors,
  libxcb,
  libx11,
  hwdata,
  seatd,
  vulkan-loader,
  glslang,
  libliftoff,
  libdisplay-info,
  lcms2,
  testers,
  enableXWayland ? true,
  xwayland ? null,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "wlroots";
  inherit version;

  inherit enableXWayland;

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "wlroots";
    repo = "wlroots";
    rev = finalAttrs.version;
    hash = src-hash;
  };

  outputs = [
    "out"
    "examples"
  ];

  depsBuildBuild = [ pkg-config ];

  nativeBuildInputs = [
    meson
    meson.configurePhaseHook
    ninja
    pkg-config
    wayland-scanner
    glslang
    hwdata
  ];

  mesonAutoFeatures = "auto";

  propagatedBuildInputs = [
    libinput
  ];

  buildInputs = [
    libliftoff
    libdisplay-info
    libGL
    libxkbcommon
    libgbm
    pixman
    seatd
    vulkan-loader
    wayland
    wayland-protocols
    libx11
    libxcb
    xcbutilerrors
    xcbutilimage
    xcbutilrenderutil
    xcbutilwm
    lcms2
    libcap
  ]
  ++ lib.optional finalAttrs.enableXWayland xwayland;

  # Suppress -Werror=switch for older wlroots versions that don't handle
  # LIBINPUT_SWITCH_KEYPAD_SLIDE (added in libinput 1.27)
  env = lib.optionalAttrs (packageOlder "0.19") {
    NIX_CFLAGS_COMPILE = "-Wno-error=switch";
  };

  mesonFlags = [
    (lib.mesonEnable "xwayland" finalAttrs.enableXWayland)
  ];

  postFixup = ''
    mkdir -p $examples/bin
    cd ./examples
    for binary in $(find . -executable -type f -printf '%P\n' | grep -vE '\.so'); do
      cp "$binary" "$examples/bin/wlroots-$binary"
    done
  '';

  passthru = mkVariantPassthru {
    tests.pkg-config = testers.hasPkgConfigModules {
      package = finalAttrs.finalPackage;
    };
  } // {
    ekapkgs-update.semver-strategy = "patch";
  };

  meta = {
    description = "Modular Wayland compositor library";
    inherit (finalAttrs.src.meta) homepage;
    changelog = "https://gitlab.freedesktop.org/wlroots/wlroots/-/tags/${version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "wlroots_project" version;
    pkgConfigModules = [
      (
        if lib.versionOlder finalAttrs.version "0.18" then
          "wlroots"
        else
          "wlroots-${lib.versions.majorMinor finalAttrs.version}"
      )
    ];
  };
})

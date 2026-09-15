{
  lib,
  stdenv,
  fetchFromGitHub,

  # build
  cmake,
  pkg-config,

  # runtime
  expat,
  ipu7-camera-bins,
  jsoncpp,
  libtool,
  gst_all_1,
  libdrm,

  # Pick one of
  # - ipu7x (Lunar Lake)
  # - ipu75xa (Arrow Lake)
  ipuVersion ? "ipu7x",
}:

stdenv.mkDerivation {
  pname = "${ipuVersion}-camera-hal";
  version = "unstable-2026-06-29";

  src = fetchFromGitHub {
    owner = "intel";
    repo = "ipu7-camera-hal";
    tag = "20260629_2";
    hash = "sha256-uiVPQBMHUBP9ZFzX0QMimIpgbmvm7JLTkD588V07iGw=";
  };

  nativeBuildInputs = [
    cmake
    cmake.configurePhaseHook
    pkg-config
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-DBUILD_CAMHAL_ADAPTOR=ON"
    "-DBUILD_CAMHAL_PLUGIN=ON"
    "-DIPU_VERSIONS=${ipuVersion}"
    "-DUSE_STATIC_GRAPH=ON"
    "-DUSE_STATIC_GRAPH_AUTOGEN=ON"
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
    # jsoncpp is linked as raw library name; help cmake find it
    "-Djsoncpp_DIR=${jsoncpp.dev}/lib/cmake/jsoncpp"
  ];

  env = {
    NIX_CFLAGS_COMPILE = toString [
      "-Wno-error"
      "-std=c++17"
    ];
    NIX_LDFLAGS = toString [ "-L${jsoncpp}/lib" ];
  };

  enableParallelBuilding = true;

  buildInputs = [
    expat
    ipu7-camera-bins
    jsoncpp
    libtool
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    libdrm
  ];

  postPatch = ''
    # jsoncpp installs headers to include/json/ but source expects jsoncpp/json/
    find . -name '*.h' -o -name '*.cpp' | xargs sed -i 's|jsoncpp/json/|json/|g'

    # CMakeLists uses raw 'jsoncpp' library name; use cmake imported target instead
    sed -i 's|set(TARGET_LINK_LIBS ''${TARGET_LINK_LIBS} jsoncpp)|find_package(jsoncpp REQUIRED)\nset(TARGET_LINK_LIBS ''${TARGET_LINK_LIBS} JsonCpp::JsonCpp)|' CMakeLists.txt

    substituteInPlace src/platformdata/PlatformData.h \
      --replace '/usr/share/' "${placeholder "out"}/share/" \
      --replace '#define CAMERA_DEFAULT_CFG_PATH "/etc/camera/"' '#define CAMERA_DEFAULT_CFG_PATH "${placeholder "out"}/etc/camera/"'
  '';

  postInstall = ''
    mkdir -p $out/include/${ipuVersion}/
    cp -r $src/include $out/include/${ipuVersion}/libcamhal
  '';

  postFixup = ''
    for lib in $out/lib/*.so; do
      patchelf --add-rpath "${ipu7-camera-bins}/lib" $lib
    done
  '';

  passthru = {
    inherit ipuVersion;
  };

  meta = {
    description = "HAL for processing of images in userspace (IPU7)";
    homepage = "https://github.com/intel/ipu7-camera-hal";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}

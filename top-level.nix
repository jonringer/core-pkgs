# This a top-level overlay which is applied after this "autoCalled" pkgs directory.
# This mainly serves as a way to define attrs at the top-level of pkgs which
# require more than just passing default arguments to nix expressions

final: prev:
let
  gstAll1 = final.lib.genAttrs [
    "gst-devtools"
    "gst-editing-services"
    "gst-libav"
    "gst-plugins-bad"
    "gst-plugins-base"
    "gst-plugins-good"
    "gst-plugins-rs"
    "gst-plugins-ugly"
    "gst-rtsp-server"
    "gstreamer"
    "gstreamermm"
  ] (_: null);
in
with final;
{

  tests = { };

  # Nix's builtin fetcher
  fetchurl-bootstrap = import ./pkgs/fetchurl/bootstrap.nix {
    inherit (stdenv.buildPlatform) system;
  };

  # The full-source bootstrap: a toolchain grown from the hex0 seed in
  # stage0-posix rather than from a prebuilt tarball. It lives in its own scope
  # so that a stray `callPackage` cannot reach a top-level package and quietly
  # reintroduce the binary seed it exists to avoid.
  #
  # The scope is built in `stdenv/linux/stage0.nix` and surfaced here, rather
  # than constructed a second time: on a system that bootstraps from source this
  # is the very toolchain `stdenv` was grown from, not a rebuild of it.
  minimal-bootstrap = stdenv.stage0.minimal-bootstrap or null;

  minimal-bootstrap-sources =
    callPackage ./stdenv/minimal-bootstrap/stage0-posix/bootstrap-sources.nix
      {
        inherit (stdenv) hostPlatform;
      };

  make-minimal-bootstrap-sources =
    callPackage ./stdenv/minimal-bootstrap/stage0-posix/make-bootstrap-sources.nix
      {
        inherit (stdenv) hostPlatform;
      };

  nix-update-script = callPackage ./pkgs/nix-update-script { };
  nix-update = null;
  nixos = null;

  qt5 = null;
  libsForQt5 = null;
  qt6 = null;
  ocamlPackages = null;

  haskell = callPackage ./haskell { inherit config; };
  haskellPackages = haskell.packages.ghc984Binary;

  # qemu_kvm - QEMU with only host CPU support (for vmTools)
  # This is required for vmTools to work correctly with direct kernel boot
  qemu_kvm = lib.lowPrio (qemu.override { hostCpuOnly = true; });

  # ekaosTest - Testing framework for ekaos systems
  ekaosTest = (callPackage ./ekaos/lib/testing { }).runTest;

  # ekaosTests - Test suite for ekaos systems (individual tests can be built)
  ekaosTests = callPackage ./ekaos/tests { };

  # integrationTests - Unified entry point for all integration test frameworks
  # Includes runitTests, ekaosTests, and future test frameworks
  integrationTests = callPackage ./integration-tests { };

  # mkDevShell - Development shell with service management
  # Creates development environments with running services using ekaos modules
  mkDevShell = (callPackage ./dev-shell { }).mkDevShell;

  # vmTools - VM building utilities for ekaosTest and disk image creation
  vmTools = callPackage ./build-support/vm { };
  makeInitrd = callPackage ./build-support/kernel/make-initrd.nix;
  makeModulesClosure = callPackage ./build-support/kernel/modules-closure.nix;
  closureInfo = callPackage ./build-support/closure-info.nix { };
  nix-gitignore = callPackage ./build-support/nix-gitignore { };

  # Default to gitMinimal to keep the fetcher's closure small; the `git`
  # argument stays overridable for callers that need a different build.
  nix-prefetch-git = callPackage ./pkgs/nix-prefetch-git { git = gitMinimal; };

  freshBootstrapTools =
    if stdenv.hostPlatform.isDarwin then
      import ./stdenv/darwin/make-bootstrap-tools.nix {
        localSystem = stdenv.buildPlatform;
        crossSystem = stdenv.hostPlatform;
      }
    else
      import ./stdenv/linux/make-bootstrap-tools.nix { pkgs = final; };

  # igraph-c alias for C library (to avoid conflict with python3Packages.igraph)
  igraph-c = igraph;

  # nv-codec-headers version aliases for ffmpeg
  nv-codec-headers-12 = nv-codec-headers.override { majorVersion = "12"; };

  # fftw precision variants; the package builds one precision per derivation
  fftwSinglePrec = fftw.override { precision = "single"; };
  fftwFloat = fftwSinglePrec; # the configure option is just an alias
  fftwLongDouble = fftw.override { precision = "long-double"; };
  # quad precision needs libquadmath, which comes from gcc
  fftwQuad = fftw.override {
    precision = "quad-precision";
    stdenv = gccStdenv;
  };

  aafigure = null;
  actdiag = null;
  amf = null; # ffmpeg
  amf-headers = null; # ffmpeg
  aria2 = null;
  aribb24 = null; # ffmpeg
  arrow-cpp = null;
  at-spi2-atk = at-spi2-core; # merged into at-spi2-core
  atk = at-spi2-core; # merged into at-spi2-core
  avisynthplus = null; # ffmpeg
  awsebcli = null;
  gsasl = null; # cursed cull option
  babel = null;
  bear = null;
  blockdiag = null;
  breathe = null;
  libidn = null; # defaultGemConfig
  capnproto = null; # defaultCrateOverrides
  celt = null; # ffmpeg
  coeurl = null;
  cppzmq = null;
  cuda_cudart = null; # ffmpeg
  cuda_nvcc = null; # ffmpeg
  cunit = null;
  curlpp = null;
  czmq = null;
  cvs = null; # nix-prefetch-cvs
  nix-prefetch-cvs = null;
  darcs = null; # nix-prefetch-darcs
  davs2 = null; # ffmpeg
  nix-prefetch-darcs = null;
  dblatex = null;
  dblatexFull = null;
  diffoscopeMinimal = null;
  distutils = null;
  dvgrab = null;
  emacs = null;
  enlightenment = null;
  epeg = null;
  epoll-shim = null; # for non-linux compat
  epubcheck = null;
  ettercap = null;
  fcitx5 = null;
  fdk_aac = null; # ffmpeg
  feh = null;
  fftwMpi = null; # needs mpi
  flite = null; # ffmpeg
  fop = null;
  frei0r = null; # ffmpeg
  game-music-emu = null; # ffmpeg
  gdal = null;
  gitstatus = null;
  gperftools = null; # libjxl `tcmalloc` support
  graphene = null; # gtk4, defaultCrateOverrides
  graphicsmagick = null;
  gst_all_1 = gstAll1; # gtk4, libde265 tests
  gsm = null; # ffmpeg
  gtkmm3 = null;
  gunicorn = null;
  highlight = null;
  ibusMinimal = null; # sdl3 `ibusSupport`; only its headers' constants are read
  icewm = null;
  imv = null; # libheif tests
  intel-media-sdk = null; # ffmpeg
  isocodes = null; # gtk3, gtk4
  jhead = null;
  jre = null;
  knot-dns = null;
  knot-resolver_5 = null;
  kvazaar = null; # ffmpeg
  ladspaH = null; # ffmpeg
  lbzip2 = null; # for conda-unpack hook
  lcevcdec = null; # ffmpeg
  libaribcaption = null; # ffmpeg
  libass = null; # ffmpeg
  libayatana-appindicator = null; # sdl3 `traySupport`
  libbluray = null; # ffmpeg
  libbs2b = null; # ffmpeg
  libcdio = null; # ffmpeg
  libcdio-paranoia = null; # ffmpeg
  libdc1394 = null; # ffmpeg
  libdvdnav = null; # ffmpeg
  libdvdread = null; # ffmpeg
  libgeotiff = null;
  libgit2-glib = null;
  libguestfs = null;
  libhwy = null; # libjxl; vendored highway from third_party is used instead
  libilbc = null; # ffmpeg
  libjack2 = null; # sdl3 `jackSupport`, ffmpeg, qemu
  liblc3 = null; # ffmpeg
  liblqr1 = null; # imagemagick, imagemagick6
  libmodplug = null; # ffmpeg
  libmysofa = null; # ffmpeg
  libnatspec = null;
  libnpp = null; # ffmpeg
  libopenmpt = null; # ffmpeg
  libraqm = null; # imagemagick
  libraw = null; # imagemagick
  libotr = null;
  libplacebo = null; # ffmpeg
  libplacebo_5 = null; # ffmpeg
  libpq = null; # defaultGemConfig, defaultCrateOverrides, gawkextlib pgsql extension
  libpulseaudio = null; # sdl3 `pulseaudioSupport`, ffmpeg, qemu
  libraw1394 = null; # ffmpeg
  librist = null; # ffmpeg
  librsvg = null; # gtk4, ffmpeg, imagemagick, djvulibre, nvidia-x11 settings, wrapGAppsHook
  libsysprof-capture = null;
  libtensorflow = null; # ffmpeg
  libtheora = null; # ffmpeg
  libv4l = null; # ffmpeg
  libvdpau = null; # ffmpeg
  libvirt = null;
  libvmaf = null; # ffmpeg
  libvpl = null; # ffmpeg
  lilypond = null;
  lmdb = null; # gawkextlib lmdb extension
  lingua = null;
  mashumaro = null;
  mathplotlib = null;
  mc = null;
  mjpegtools = null;
  mkdocs = null;
  mosquitto = null;
  mpd = null;
  mpi = null; # fftwMpi
  mscgen = null;
  multipath-tools = null;
  neovim = null;
  nodejs_latest = nodejs.v26;
  nwdiag = null;
  nixos-icons = null; # imagemagick tests
  objgraph = null;
  objprint = null; # for pytestCheckHook
  openal = null; # ffmpeg
  openapv = null; # ffmpeg
  openbox = null;
  opencore-amr = null; # ffmpeg
  openexr = null; # imagemagick, imagemagick6, libjxl
  opencv = null;
  openh264 = null; # ffmpeg
  openimageio = null;
  ostinato = null;
  pipewire = null; # sdl3 `pipewireSupport`, qemu, alsa-lib; needs gstreamer, libsndfile, lilv
  pika = null;
  pinentry = null;
  psutils = null;
  pydantic = null;
  pygame-ce = null;
  quart = null;
  quirc = null; # ffmpeg
  rapidjson = null; # gawkextlib json extension
  rav1e = null; # libheif AV1 encoding; libaom still provides it
  rdkafka = null; # defaultCrateOverrides
  rich = null;
  rubberband = null; # ffmpeg
  sage = null;
  samba = null;
  sassc = null; # gtk3, gtk4
  sbclPackages = null;
  scribus = null;
  seqdiag = null;
  setproctitle = null;
  shaderc = null; # ffmpeg, gtk4
  shine = null; # ffmpeg
  sndio = null; # sdl3 `sndioSupport`, off on every platform
  spamassassin = null;
  speex = null; # ffmpeg
  squid = null;
  subversionClient = null;
  tcpreplay = null;
  termcap = null;
  texmacs = null;
  tigervnc = null;
  tiledb = null;
  tinysparql = null;
  tornado = null;
  tracee = null;
  tre = null; # gawkextlib aregex extension
  trustme = null;
  ttfautohint = null;
  twolame = null; # ffmpeg
  uavs3d = null; # ffmpeg
  uwsgi = null;
  vid-stab = null; # ffmpeg
  vips = null;
  vo-amrwbenc = null; # ffmpeg
  vvenc = null; # ffmpeg
  werkzeug = null;
  whisper-cpp = null; # ffmpeg
  wireshark = null;
  xavs = null; # ffmpeg
  xavs2 = null; # ffmpeg
  xevd = null; # ffmpeg
  xeve = null; # ffmpeg
  xvidcore = null; # ffmpeg
  yallback = null;
  yamllint = null;
  yara = null;
  zmqpp = null;
  zvbi = null; # ffmpeg

  ocl-icd = null; # ffmpeg OpenCL ICD
  opencl-headers = null; # ffmpeg
  xcodebuild = xcbuild;

  # Darwin packages use the ordinary package scope and shared package directories.
  bootstrapStdenv = stdenv.override (old: {
    extraBuildInputs = map (
      pkg:
      if lib.isDerivation pkg && lib.getName pkg == "apple-sdk" then
        pkg.override { enableBootstrap = true; }
      else
        pkg
    ) (old.extraBuildInputs or [ ]);
  });

  inherit (llvmPackages) clang-unwrapped;
  inherit (file_cmds) xattr;
  xarMinimal = callPackage ./pkgs/xar { e2fsprogs = null; };

  apple-sdk_14 = apple-sdk.override { darwinSdkMajorVersion = "14"; };
  apple-sdk_15 = apple-sdk.override { darwinSdkMajorVersion = "15"; };
  apple-sdk_26 = apple-sdk.override { darwinSdkMajorVersion = "26"; };
  inherit (callPackage ./pkgs/xcode { })
    requireXcode
    xcode_8_1
    xcode_8_2
    xcode_9_1
    xcode_9_2
    xcode_9_3
    xcode_9_4
    xcode_9_4_1
    xcode_10_1
    xcode_10_2
    xcode_10_2_1
    xcode_10_3
    xcode_11
    xcode_11_1
    xcode_11_2
    xcode_11_3
    xcode_11_3_1
    xcode_11_4
    xcode_11_5
    xcode_11_6
    xcode_11_7
    xcode_12
    xcode_12_0_1
    xcode_12_1
    xcode_12_2
    xcode_12_3
    xcode_12_4
    xcode_12_5
    xcode_12_5_1
    xcode_13
    xcode_13_1
    xcode_13_2
    xcode_13_2_1
    xcode_13_3
    xcode_13_3_1
    xcode_13_4
    xcode_13_4_1
    xcode_14
    xcode_14_1
    xcode_15
    xcode_15_0_1
    xcode_15_1
    xcode_15_2
    xcode_15_3
    xcode_15_4
    xcode_16
    xcode_16_1
    xcode_16_2
    xcode_16_3
    xcode_16_4
    xcode_26
    xcode_26_Apple_silicon
    xcode_26_0_1
    xcode_26_0_1_Apple_silicon
    xcode_26_1
    xcode_26_1_Apple_silicon
    xcode_26_1_1
    xcode_26_1_1_Apple_silicon
    xcode_26_2
    xcode_26_2_Apple_silicon
    xcode_26_3
    xcode_26_3_Apple_silicon
    xcode_26_4
    xcode_26_4_Apple_silicon
    xcode_26_4_1
    xcode_26_4_1_Apple_silicon
    xcode_26_5
    xcode_26_5_Apple_silicon
    xcode_26_6
    xcode_26_6_Apple_silicon
    xcode
    ;

  # TODO(corepkgs): support windows
  windows = null;
  libgnurx = null;

  # Non-GNU/Linux OSes are currently "impure" platforms, with their libc
  # outside of the store.  Thus, GCC, GFortran, & co. must always look for files
  # in standard system directories (/usr/include, etc.)
  noSysDirs =
    stdenv.buildPlatform.system != "x86_64-solaris"
    && stdenv.buildPlatform.system != "x86_64-kfreebsd-gnu";

  mkManyVariants = callFromScope ./pkgs/mkManyVariants { };

  # A stdenv capable of building 32-bit binaries.
  # On x86_64-linux, it uses GCC compiled with multilib support; on i686-linux,
  # it's just the plain stdenv.
  stdenv_32bit = lib.lowPrio (if stdenv.hostPlatform.is32bit then stdenv else multiStdenv);

  mkStdenvNoLibs =
    stdenv:
    let
      bintools = stdenv.cc.bintools.override {
        libc = null;
        noLibc = true;
      };
    in
    stdenv.override {
      cc = stdenv.cc.override {
        libc = null;
        noLibc = true;
        extraPackages = [ ];
        inherit bintools;
      };
      allowedRequisites = lib.mapNullable (rs: rs ++ [ bintools ]) (stdenv.allowedRequisites or null);
    };

  stdenvNoLibs =
    if stdenvNoCC.hostPlatform != stdenvNoCC.buildPlatform then
      # We cannot touch binutils or cc themselves, because that will cause
      # infinite recursion. So instead, we just choose a libc based on the
      # current platform. That means we won't respect whatever compiler was
      # passed in with the stdenv stage argument.
      #
      # TODO It would be much better to pass the `stdenvNoCC` and *unwrapped*
      # cc, bintools, compiler-rt equivalent, etc. and create all final stdenvs
      # as part of the stage. Then we would never be tempted to override a later
      # thing to to create an earlier thing (leading to infinite recursion) and
      # we also would still respect the stage arguments choices for these
      # things.
      (
        if stdenvNoCC.hostPlatform.isDarwin || stdenvNoCC.hostPlatform.useLLVM or false then
          overrideCC stdenvNoCC buildPackages.llvmPackages.clangNoCompilerRt
        else
          gccCrossLibcStdenv
      )
    else
      mkStdenvNoLibs stdenv;

  stdenvNoLibc =
    if stdenvNoCC.hostPlatform != stdenvNoCC.buildPlatform then
      (
        if stdenvNoCC.hostPlatform.isDarwin || stdenvNoCC.hostPlatform.useLLVM or false then
          overrideCC stdenvNoCC buildPackages.llvmPackages.clangNoLibc
        else
          gccCrossLibcStdenv
      )
    else
      mkStdenvNoLibs stdenv;

  gccStdenvNoLibs = mkStdenvNoLibs gccStdenv;
  clangStdenvNoLibs = mkStdenvNoLibs clangStdenv;

  glibc = callPackage ./pkgs/glibc (
    if stdenv.hostPlatform != stdenv.buildPlatform then
      {
        stdenv = gccCrossLibcStdenv; # doesn't compile without gcc
        # Separate from pkgs/gcc/common/libgcc.nix — different bootstrap stage
        libgcc = callPackage ./pkgs/glibc/libgcc-for-glibc.nix {
          gcc = gccCrossLibcStdenv.cc;
          glibc = glibc.override { libgcc = null; };
          stdenvNoLibs = gccCrossLibcStdenv;
        };
      }
    else
      {
        stdenv = gccStdenv; # doesn't compile without gcc
      }
  );

  # Only supported on Linux and only on glibc
  glibcLocales =
    if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isGnu then
      callPackage ./pkgs/glibc/locales.nix {
        stdenv = if (!stdenv.cc.isGNU) then gccStdenv else stdenv;
        withLinuxHeaders = !stdenv.cc.isGNU;
      }
    else
      null;
  glibcLocalesUtf8 =
    if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isGnu then
      callPackage ./pkgs/glibc/locales.nix {
        stdenv = if (!stdenv.cc.isGNU) then gccStdenv else stdenv;
        withLinuxHeaders = !stdenv.cc.isGNU;
        allLocales = false;
      }
    else
      null;

  glibcInfo = callPackage ./pkgs/glibc/info.nix { };

  glibc_multi = callPackage ./pkgs/glibc/multi.nix {
    # The buildPackages is required for cross-compilation. The pkgsi686Linux set
    # has target and host always set to the same value based on target platform
    # of the current set. We need host to be same as build to correctly get i686
    # variant of glibc.
    glibc32 = pkgsi686Linux.buildPackages.glibc;
  };

  libc =
    let
      inherit (stdenv.hostPlatform) libc;
      # libc is hackily often used from the previous stage. This `or`
      # hack fixes the hack, *sigh*.
    in
    if libc == null then
      null
    else if libc == "glibc" then
      glibc
    else if libc == "bionic" then
      bionic
    else if libc == "uclibc" then
      uclibc
    else if libc == "avrlibc" then
      avrlibc
    else if libc == "newlib" && stdenv.hostPlatform.isMsp430 then
      msp430Newlib
    else if libc == "newlib" && stdenv.hostPlatform.isVc4 then
      vc4-newlib
    else if libc == "newlib" && stdenv.hostPlatform.isOr1k then
      or1k-newlib
    else if libc == "newlib" then
      newlib
    else if libc == "newlib-nano" then
      newlib-nano
    else if libc == "musl" then
      musl
    else if libc == "msvcrt" then
      windows.mingw_w64
    else if libc == "ucrt" then
      windows.mingw_w64
    else if libc == "libSystem" then
      if stdenv.hostPlatform.useiOSPrebuilt then iosSdkPkgs.libraries else libSystem
    else if libc == "fblibc" then
      freebsd.libc
    else if libc == "oblibc" then
      openbsd.libc
    else if libc == "nblibc" then
      netbsd.libc
    else if libc == "wasilibc" then
      wasilibc
    else if libc == "relibc" then
      relibc
    else if name == "llvm" then
      llvmPackages_20.libc
    else
      throw "Unknown libc ${libc}";

  lit = with python3Packages; toPythonApplication lit;

  binutils_nogold = lib.lowPrio (wrapBintoolsWith {
    bintools = binutils.unwrapped.real.override {
      enableGold = false;
    };
  });

  libbfd = callPackage ./pkgs-many/binutils/libbfd.nix { };

  libopcodes = callPackage ./pkgs-many/binutils/libopcodes.nix { };

  libbfd_2_38 = callPackage ./pkgs-many/binutils/2.38/libbfd.nix {
    autoreconfHook = buildPackages.autoconf.v2_69.autoreconfHook;
  };

  libopcodes_2_38 = callPackage ./pkgs-many/binutils/2.38/libopcodes.nix {
    autoreconfHook = buildPackages.autoconf.v2_69.autoreconfHook;
  };

  # Here we select the default bintools implementations to be used.  Note when
  # cross compiling these are used not for this stage but the *next* stage.
  # That is why we choose using this stage's target platform / next stage's
  # host platform.
  #
  # Because this is the *next* stages choice, it's a bit non-modular to put
  # here. In theory, bootstrapping is supposed to not be a chain but at tree,
  # where each stage supports many "successor" stages, like multiple possible
  # futures. We don't have a better alternative, but with this downside in
  # mind, please be judicious when using this attribute. E.g. for building
  # things in *this* stage you should use probably `stdenv.cc.bintools` (from a
  # default or alternate `stdenv`), at build time, and try not to "force" a
  # specific bintools at runtime at all.
  #
  # In other words, try to only use this in wrappers, and only use those
  # wrappers from the next stage.
  bintools-unwrapped =
    let
      inherit (stdenv.targetPlatform) linker;
    in
    if linker == "lld" then
      llvmPackages.bintools-unwrapped
    else if linker == "cctools" then
      binutils.unwrapped
    else if linker == "bfd" then
      binutils.unwrapped
    else if linker == "gold" then
      binutils.unwrapped.override { enableGoldDefault = true; }
    else
      null;
  bintoolsNoLibc = wrapBintoolsWith {
    bintools = bintools-unwrapped;
    libc = targetPackages.preLibcHeaders or preLibcHeaders;
  };
  bintools = wrapBintoolsWith {
    bintools = bintools-unwrapped;
  };

  xorg =
    let
      # Backward-compatibility alias set: maps legacy xorg.* attr names to top-level packages.
      aliases = import ./pkgs/xorg { inherit lib; };
      aliasSet = aliases __splicedPackages;
    in
    lib.recurseIntoAttrs aliasSet;

  zlib-ng-compat = zlib-ng.override { withZlibCompat = true; };

  makeDBusConf = callPackage ./pkgs/dbus/make-dbus-conf.nix { };

  fetchpatch =
    callPackage ./pkgs/fetchpatch {
      # 0.3.4 would change hashes: https://github.com/NixOS/nixpkgs/issues/25154
      patchutils = __splicedPackages.patchutils_0_3_3;
    }
    // {
      version = 1;
    };
  fetchpatch2 =
    callPackage ./pkgs/fetchpatch {
      patchutils = __splicedPackages.patchutils_0_4_2;
    }
    // {
      version = 2;
    };
  # TODO: proper freebsd port
  freebsd = { };

  fts = if stdenv.hostPlatform.isMusl then musl-fts else null;

  inherit (callPackages ./build-support/setup-hooks/patch-rc-path-hooks { })
    patchRcPathBash
    patchRcPathCsh
    patchRcPathFish
    patchRcPathPosix
    ;

  shortenPerlShebang = makeSetupHook {
    name = "shorten-perl-shebang-hook";
    propagatedBuildInputs = [ dieHook ];
  } ./build-support/setup-hooks/shorten-perl-shebang.sh;

  copyPkgconfigItems = makeSetupHook {
    name = "copy-pkg-config-items-hook";
  } ./build-support/setup-hooks/copy-pkgconfig-items.sh;
  fixDarwinDylibNames = callPackage (
    {
      lib,
      targetPackages,
      makeSetupHook,
    }:
    makeSetupHook {
      name = "fix-darwin-dylib-names-hook";
      substitutions = { inherit (targetPackages.stdenv.cc) targetPrefix; };
      meta.platforms = lib.platforms.darwin;
    } ./build-support/setup-hooks/fix-darwin-dylib-names.sh
  ) { };

  json-schema-for-humans = with python3Packages; toPythonApplication json-schema-for-humans;

  makeAutostartItem = callPackage ./build-support/make-startupitem { };
  makeDesktopItem = callPackage ./build-support/make-desktopitem { };
  copyDesktopItems = makeSetupHook {
    name = "copy-desktop-items-hook";
  } ./build-support/setup-hooks/copy-desktop-items.sh;

  makePkgconfigItem = callPackage ./build-support/make-pkgconfigitem { };

  # Default libGL implementation.
  #
  # Android NDK provides an OpenGL implementation, we can just use that.
  #
  # On macOS, the SDK provides the OpenGL framework in `stdenv`.
  # Packages that still need GLX specifically can pull in `libGLX`
  # instead. If you have a package that should work without X11 but it
  # can’t find the library, it may help to add the path to
  # `$NIX_CFLAGS_COMPILE`:
  #
  #    preConfigure = ''
  #      export NIX_CFLAGS_COMPILE+=" -L$SDKROOT/System/Library/Frameworks/OpenGL.framework/Versions/Current/Libraries"
  #    '';
  #
  libGL =
    if stdenv.hostPlatform.useAndroidPrebuilt then
      stdenv
    else if stdenv.hostPlatform.isDarwin then
      null
    else
      libglvnd;

  libGLU = mesa_glu;

  # `libglvnd` does not work (yet?) on macOS.
  libGLX = if stdenv.hostPlatform.isDarwin then mesa else libglvnd;

  # On macOS, the SDK provides the GLUT framework in `stdenv`. Packages
  # that use `libGLX` on macOS may need to depend on `freeglut`
  # directly if this doesn’t work.
  libglut = freeglut;
  libva-minimal = callPackage ./pkgs/libva { minimal = true; };
  mesa = callPackage ./pkgs/mesa { };
  mesa_i686 = null; # TODO(corepkgs): needs pkgsi686Linux
  libgbm = callPackage ./pkgs/mesa/gbm.nix { };
  mesa-gl-headers = callPackage ./pkgs/mesa/headers.nix { };

  # variant of qemu building user space emulator only - intended to be used from pkgsStatic
  qemu-user = qemu.override {
    userOnly = true;
  };

  wrapQemuBinfmtP = callPackage ./pkgs/qemu/binfmt-p-wrapper.nix { };

  libxcrypt = callPackage ./pkgs/libxcrypt {
    fetchurl = fetchurl-bootstrap;
    perl = buildPackages.perl.override {
      enableCrypt = false;
      fetchurl = fetchurl-bootstrap;
    };
  };

  # TODO: Remove alias
  libjpeg = libjpeg_turbo;

  # Less secure variant of lowdown for use inside Nix builds.
  lowdown-unsandboxed = lowdown.override {
    enableDarwinSandbox = false;
  };

  generateLdCacheHook =
    makeSetupHook
      {
        name = "generate-ld-cache-hook";
        # TODO: Remove once makeSetupHook defaults __structuredAttrs to true.
        __structuredAttrs = true;
      }
      (
        replaceVars ./build-support/setup-hooks/generate-ld-cache.sh {
          patchelf = "${patchelf}/bin/patchelf";
        }
      );

  # These are used when building compiler-rt / libgcc, prior to building libc.
  preLibcHeaders =
    let
      inherit (stdenv.hostPlatform) libc;
    in
    if stdenv.hostPlatform.isMinGW then
      windows.mingw_w64_headers or fallback
    else if libc == "nblibc" then
      netbsd.headers
    else if libc == "cygwin" then
      cygwin.newlib-cygwin-headers
    else
      null;

  po4a = perlPackages.Po4a;

  pnpmConfigHook = callPackage ./pkgs/pnpmConfigHook { };
  fetchPnpmDeps = callPackage ./pkgs/fetchPnpmDeps { };

  inherit (callPackages ./pkgs/fetchYarnDeps { })
    fetchYarnDeps
    fixup-yarn-lock
    prefetch-yarn-deps
    yarnConfigHook
    yarnBuildHook
    yarnInstallHook
    ;

  procps = if stdenv.hostPlatform.isLinux then procps-ng else unixtools.procps;

  pruneLibtoolFiles = makeSetupHook {
    name = "prune-libtool-files";
  } ./build-support/setup-hooks/prune-libtool-files.sh;

  default-gcc-version = 14;
  gcc = pkgs.${"gcc${toString default-gcc-version}"};
  gccFun = callPackage ./pkgs/gcc;
  gcc-unwrapped = gcc.cc;
  libgcc = stdenv.cc.cc.libgcc or null;

  # This is for e.g. LLVM libraries on linux.
  gccForLibs =
    if
      stdenv.targetPlatform == stdenv.hostPlatform && targetPackages.stdenv.cc.isGNU
    # Can only do this is in the native case, otherwise we might get infinite
    # recursion if `targetPackages.stdenv.cc.cc` itself uses `gccForLibs`.
    then
      targetPackages.stdenv.cc.cc
    else
      gcc.cc;

  inherit
    (rec {
      # NOTE: keep this with the "NG" label until we're ready to drop the monolithic GCC
      gccNGPackagesSet = lib.recurseIntoAttrs (callPackages ./pkgs/gcc/ng { });
      gccNGPackages_15 = gccNGPackagesSet."15";
      mkGCCNGPackages = gccNGPackagesSet.mkPackage;
    })
    gccNGPackages_15
    mkGCCNGPackages
    ;

  wrapNonDeterministicGcc =
    stdenv: ccWrapper:
    if ccWrapper.isGNU then
      ccWrapper.overrideAttrs (old: {
        env = old.env // {
          cc = old.env.cc.override {
            reproducibleBuild = false;
            profiledCompiler = with stdenv.hostPlatform; (!isDarwin && isx86);
          };
        };
      })
    else
      ccWrapper;

  gfortran = wrapCC (
    gcc.cc.override {
      name = "gfortran";
      langFortran = true;
      langCC = false;
      langC = false;
      profiledCompiler = false;
    }
  );

  gobject-introspection-unwrapped = callPackage ./pkgs/gobject-introspection/unwrapped.nix { };

  buildGoModule = go.buildModule;

  R = callPackage ./pkgs/R { };

  buildRPackage = callPackage ./build-support/r { };

  rPackages = callPackage ./r { inherit config; };

  buildMavenPackage = java.buildMavenPackage;
  buildGradlePackage = java.buildGradlePackage;
  buildNpmPackage = nodejs.buildNpmPackage;
  buildNpmApplication = nodejs.buildNpmApplication;
  buildPnpmApplication = nodejs.buildPnpmApplication;
  buildYarnApplication = nodejs.buildYarnApplication;

  gnome = callPackage ./pkgs/gnome { };

  gnuStdenv =
    if stdenv.cc.isGNU then
      stdenv
    else
      gccStdenv.override {
        cc = gccStdenv.cc.override {
          bintools = buildPackages.binutils;
        };
      };

  gccStdenv =
    if stdenv.cc.isGNU then
      stdenv
    else
      stdenv.override {
        cc = buildPackages.gcc;
        allowedRequisites = null;
        # Remove libcxx/libcxxabi, and add clang for AS if on darwin (it uses
        # clang's internal assembler).
        extraBuildInputs = lib.optional stdenv.hostPlatform.isDarwin clang.cc;
      };

  gcc13Stdenv = overrideCC gccStdenv buildPackages.gcc13;
  gcc14Stdenv = overrideCC gccStdenv buildPackages.gcc14;
  gcc15Stdenv = overrideCC gccStdenv buildPackages.gcc15;

  # This is not intended for use in nixpkgs but for providing a faster-running
  # compiler to nixpkgs users by building gcc with reproducibility-breaking
  # profile-guided optimizations
  fastStdenv = overrideCC gccStdenv (wrapNonDeterministicGcc gccStdenv buildPackages.gcc_latest);

  wrapCCMulti =
    cc:
    let
      # Binutils with glibc multi
      bintools = cc.bintools.override {
        libc = glibc_multi;
      };
    in
    lib.lowPrio (wrapCCWith {
      cc = cc.cc.override {
        stdenv = overrideCC stdenv (wrapCCWith {
          cc = cc.cc;
          inherit bintools;
          libc = glibc_multi;
        });
        profiledCompiler = false;
        enableMultilib = true;
      };
      libc = glibc_multi;
      inherit bintools;
      extraBuildCommands = ''
        echo "dontMoveLib64=1" >> $out/nix-support/setup-hook
      '';
    });

  # TODO(corepkgs): port llvm/multi.nix for clang multilib support
  wrapClangMulti =
    clang: throw "clang_multi is not yet available in core-pkgs (needs llvm/multi.nix ported)";

  gcc_multi = wrapCCMulti gcc;
  clang_multi = wrapClangMulti clang;

  gccMultiStdenv = overrideCC stdenv buildPackages.gcc_multi;
  clangMultiStdenv = overrideCC stdenv buildPackages.clang_multi;
  multiStdenv = if stdenv.cc.isClang then clangMultiStdenv else gccMultiStdenv;

  gcc_debug = lib.lowPrio (
    wrapCC (
      gcc.cc.overrideAttrs {
        dontStrip = true;
      }
    )
  );

  gccCrossLibcStdenv = overrideCC stdenvNoCC buildPackages.gccWithoutTargetLibc;

  # The GCC used to build libc for the target platform. Normal gccs will be
  # built with, and use, that cross-compiled libc.
  gccWithoutTargetLibc =
    let
      libc1 = binutils.noLibc.libc;
    in
    (wrapCCWith {
      cc = gccFun {
        # copy-pasted
        inherit noSysDirs;
        majorMinorVersion = toString default-gcc-version;

        reproducibleBuild = true;
        profiledCompiler = false;

        isl = if !stdenv.hostPlatform.isDarwin then isl else null;

        withoutTargetLibc = true;
        langCC = stdenv.targetPlatform.isCygwin; # can't compile libcygwin1.a without C++
        libcCross = libc1;
        targetPackages.stdenv.cc.bintools = binutils.noLibc;
        enableShared =
          stdenv.targetPlatform.hasSharedLibraries

          # temporarily disabled due to breakage;
          # see https://github.com/NixOS/nixpkgs/pull/243249
          && !stdenv.targetPlatform.isWindows
          && !stdenv.targetPlatform.isCygwin
          && !(stdenv.targetPlatform.useLLVM or false);
      };
      bintools = binutils.noLibc;
      libc = libc1;
      extraPackages = [ ];
    }).overrideAttrs
      (prevAttrs: {
        meta = prevAttrs.meta // {
          badPlatforms =
            (prevAttrs.meta.badPlatforms or [ ])
            ++ lib.optionals (stdenv.targetPlatform == stdenv.hostPlatform) [ stdenv.hostPlatform.system ];
        };
      });

  # gcc-releases is auto-imported from pkgs-many/gcc-releases/ via mkManyVariants
  # Individual versions: gcc-releases.v13, gcc-releases.v14, gcc-releases.v15
  gcc13 = gcc-releases.v13;
  gcc14 = gcc-releases.v14;
  gcc15 = gcc-releases.v15;

  gcc_latest = gcc15;

  libgccjit = gcc.cc.override {
    name = "libgccjit";
    langFortran = false;
    langCC = false;
    langC = false;
    profiledCompiler = false;
    langJit = true;
    enableLTO = false;
  };

  # Utility to extract just the source from a derivation
  srcOnly =
    args:
    (callPackage (
      {
        runCommand,
        lib,
        stdenvNoCC,
      }:
      drv:
      runCommand "${drv.name}-src"
        {
          outputs = [ "out" ];
          preferLocalBuild = true;
        }
        ''
          mkdir -p $out
          ${lib.concatMapStringsSep "\n" (output: ''
            if [ -d "${drv.${output}}" ]; then
              cp -r "${drv.${output}}"/* $out/
            fi
          '') (drv.outputs or [ "out" ])}
        ''
    ) { } args);

  wrapCCWith =
    {
      cc,
      # This should be the only bintools runtime dep with this sort of logic. The
      # Others should instead delegate to the next stage's choice with
      # `targetPackages.stdenv.cc.bintools`. This one is different just to
      # provide the default choice, avoiding infinite recursion.
      # See the bintools attribute for the logic and reasoning. We need to provide
      # a default here, since eval will hit this function when bootstrapping
      # stdenv where the bintools attribute doesn't exist, but will never actually
      # be evaluated -- callPackage ends up being too eager.
      bintools ? pkgs.bintools,
      libc ? bintools.libc,
      # libc++ from the default LLVM version is bound at the top level, but we
      # want the C++ library to be explicitly chosen by the caller, and null by
      # default.
      libcxx ? null,
      extraPackages ? [ ],
      nixSupport ? { },
      ...
    }@extraArgs:
    callPackage ./build-support/cc-wrapper (
      let
        self = {
          nativeTools = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeTools or false;
          nativeLibc = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeLibc or false;
          nativePrefix = stdenv.cc.nativePrefix or "";
          noLibc = !self.nativeLibc && (self.libc == null);

          isGNU = cc.isGNU or false;
          isClang = cc.isClang or false;
          isArocc = cc.isArocc or false;
          isZig = cc.isZig or false;

          inherit
            lib
            cc
            bintools
            libc
            libcxx
            extraPackages
            nixSupport
            ;
        }
        // extraArgs;
      in
      self
    );
  wrapCC =
    cc:
    wrapCCWith {
      inherit cc;
    };
  wrapBintoolsWith =
    {
      bintools,
      libc ? targetPackages.libc or pkgs.libc,
      ...
    }@extraArgs:
    callPackage ./build-support/bintools-wrapper (
      let
        self = {
          nativeTools = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeTools or false;
          nativeLibc = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeLibc or false;
          nativePrefix = stdenv.cc.nativePrefix or "";

          noLibc = (self.libc == null);

          inherit bintools libc;
        }
        // extraArgs;
      in
      self
    );
  removeReferencesTo = callPackage ./build-support/remove-references-to { };
  replaceVarsWith = callPackage ./build-support/replace-vars/replace-vars-with.nix { };
  replaceVars = callPackage ./build-support/replace-vars/replace-vars.nix { };
  substituteAll = callPackage ./build-support/substitute-all/substitute-all.nix { };
  replaceDirectDependencies = callPackage ./build-support/replace-direct-dependencies.nix { };

  devShellTools = callPackage ./build-support/dev-shell-tools { };

  # Docker and OCI container tools
  dockerTools = callPackage ./build-support/docker {
    writePython3 = buildPackages.writers.writePython3;
    inherit devShellTools;
  };
  ociTools = callPackage ./build-support/oci-tools { };

  # Helper tools for dockerTools
  tarsum = callPackage ./build-support/docker/tarsum.nix { };
  nix-prefetch-docker = callPackage ./build-support/docker/nix-prefetch-docker.nix { };
  dockerAutoLayer = callPackage ./build-support/docker/auto-layer.nix { };
  dockerMakeLayers = callPackage ./build-support/docker/make-layers.nix { };
  fakeNss = callPackage ./build-support/fake-nss { };

  runUnitTests = pkg: pkg.overrideAttrs { doCheck = true; };
  runtimeShell = "${runtimeShellPackage}${runtimeShellPackage.shellPath}";
  runtimeShellPackage = bashNonInteractive;
  bash = callPackage ./pkgs/bash/5.nix { };
  bashNonInteractive = lib.lowPrio (
    callPackage ./pkgs/bash/5.nix {
      interactive = false;
    }
  );
  # WARNING: this attribute is used by nix-shell so it shouldn't be removed/renamed
  bashInteractive = bash;
  bashFHS = callPackage ./pkgs/bash/5.nix {
    forFHSEnv = true;
  };
  bashInteractiveFHS = bashFHS;

  # Python interpreters. All standard library modules are included except for tkinter, which is
  # available as `pythonPackages.tkinter` and can be used as any other Python package.
  python = python3;
  python2 = python27;
  python3 = python313;

  # pythonPackages further below, but assigned here because they need to be in sync
  python2Packages = lib.dontRecurseIntoAttrs python27Packages;
  python3Packages = lib.dontRecurseIntoAttrs python313Packages;

  pypy = pypy2;
  pypy2 = pypy27;
  pypy3 = pypy311;

  # Python interpreter that is build with all modules, including tkinter.
  # These are for compatibility and should not be used inside Nixpkgs.
  python2Full = python2.override {
    self = python2Full;
    pythonAttr = "python2Full";
    x11Support = true;
  };
  python27Full = python27.override {
    self = python27Full;
    pythonAttr = "python27Full";
    x11Support = true;
  };

  # https://py-free-threading.github.io
  python313FreeThreading = python313.override {
    self = python313FreeThreading;
    pythonAttr = "python313FreeThreading";
    enableGIL = false;
  };
  python314FreeThreading = python314.override {
    self = python314FreeThreading;
    pythonAttr = "python314FreeThreading";
    enableGIL = false;
  };
  python315FreeThreading = python315.override {
    self = python315FreeThreading;
    pythonAttr = "python315FreeThreading";
    enableGIL = false;
  };

  pythonInterpreters = callPackage ./python { inherit config; };
  inherit (pythonInterpreters)
    python27
    python310
    python311
    python312
    python313
    python314
    python315
    python3Minimal
    pypy27
    pypy310
    pypy311
    ;

  # Python package sets.
  python27Packages = python27.pkgs;
  python310Packages = python310.pkgs;
  python311Packages = python311.pkgs;
  python312Packages = lib.recurseIntoAttrs python312.pkgs;
  python313Packages = lib.recurseIntoAttrs python313.pkgs;
  python314Packages = python314.pkgs;
  python315Packages = python315.pkgs;
  pypyPackages = pypy.pkgs;
  pypy2Packages = pypy2.pkgs;
  pypy27Packages = pypy27.pkgs;
  pypy3Packages = pypy3.pkgs;
  pypy310Packages = pypy310.pkgs;
  pypy311Packages = pypy311.pkgs;

  pythonManylinuxPackages = callPackage ./python/manylinux { };

  pythonCondaPackages = callPackage ./python/conda { };

  # Should eventually be moved inside Python interpreters.
  python-setup-hook = buildPackages.callPackage ./python/setup-hook.nix { };

  pythonDocs = lib.recurseIntoAttrs (callPackage ./python/cpython/docs { });

  # Provided by libc on Operating Systems that use the Extensible Linker Format.
  elf-header = if stdenv.hostPlatform.isElf then null else elf-header-real;

  inherit
    (callPackages ./pkgs/linux-support/pkgs/kernel-headers { inherit (pkgsBuildBuild) elf-header; })
    linuxHeaders
    makeLinuxHeaders
    ;

  # while building documentation meson may want to run binaries for host
  # which needs an emulator
  # example of an error which this fixes
  # [Errno 8] Exec format error: './gdk3-scan'
  mesonEmulatorHook =
    makeSetupHook
      {
        name = "mesonEmulatorHook";
        substitutions = {
          crossFile = writeText "cross-file.conf" ''
            [binaries]
            exe_wrapper = '${lib.escape [ "'" "\\" ] (stdenv.targetPlatform.emulator pkgs)}'
          '';
        };
      }
      # The throw is moved into the `makeSetupHook` derivation, so that its
      # outer level, but not its outPath can still be evaluated if the condition
      # doesn't hold. This ensures that splicing still can work correctly.
      (
        if (!stdenv.hostPlatform.canExecute stdenv.targetPlatform) then
          ./pkgs/meson/emulator-hook.sh
        else
          throw "mesonEmulatorHook may only be added to nativeBuildInputs when the target binaries can't be executed; however you are attempting to use it in a situation where ${stdenv.hostPlatform.config} can execute ${stdenv.targetPlatform.config}. Consider only adding mesonEmulatorHook according to a conditional based canExecute in your package expression."
      );

  coreutils = callPackage ./pkgs/coreutils { };

  # The coreutils above is built with dependencies from
  # bootstrapping. We cannot override it here, because that pulls in
  # openssl from the previous stage as well.
  coreutils-full = callPackage ./pkgs/coreutils { minimal = false; };
  coreutils-prefixed = coreutils.override {
    withPrefix = true;
    singleBinary = false;
  };

  iconv =
    if
      lib.elem stdenv.hostPlatform.libc [
        "glibc"
        "musl"
      ]
    then
      lib.getBin libc
    else if stdenv.hostPlatform.isDarwin then
      lib.getBin libiconv
    else if stdenv.hostPlatform.isFreeBSD then
      lib.getBin freebsd.iconv
    else
      lib.getBin prev.libiconv;

  openssl_legacy = openssl.override {
    conf = ./pkgs-many/openssl/3.0/legacy.cnf;
  };

  makeWrapper = makeShellWrapper;
  makeShellWrapper = makeSetupHook {
    name = "make-shell-wrapper-hook";
    propagatedBuildInputs = [ dieHook ];
    substitutions = {
      # targetPackages.runtimeShell only exists when pkgs == targetPackages (when targetPackages is not  __raw)
      shell =
        if targetPackages ? runtimeShell then
          targetPackages.runtimeShell
        else
          throw "makeWrapper/makeShellWrapper must be in nativeBuildInputs";
    };
  } ./build-support/setup-hooks/make-wrapper.sh;
  __flattenIncludeHackHook = callPackage ./build-support/setup-hooks/flatten-include-hack { };
  dieHook = makeSetupHook {
    name = "die-hook";
  } ./build-support/setup-hooks/die.sh;
  findXMLCatalogs = makeSetupHook {
    name = "find-xml-catalogs-hook";
  } ./build-support/setup-hooks/find-xml-catalogs.sh;
  arrayUtilities =
    let
      arrayUtilitiesPackages = makeScopeWithSplicing' {
        otherSplices = generateSplicesForMkScope "arrayUtilities";
        f =
          finalArrayUtilities:
          {
            callPackages = lib.callPackagesWith (pkgs // finalArrayUtilities);
          }
          // lib.packagesFromDirectoryRecursive {
            inherit (finalArrayUtilities) callPackage;
            directory = ./build-support/setup-hooks/arrayUtilities;
          };
      };
    in
    lib.recurseIntoAttrs arrayUtilitiesPackages;
  addBinToPathHook = callPackage (
    { makeSetupHook }:
    makeSetupHook {
      name = "add-bin-to-path-hook";
    } ./build-support/setup-hooks/add-bin-to-path.sh
  ) { };
  autoPatchelfHook = makeSetupHook {
    name = "auto-patchelf-hook";
    propagatedBuildInputs = [
      auto-patchelf
      bintools
    ];
    substitutions = {
      hostPlatform = stdenv.hostPlatform.config;
    };
  } ./build-support/setup-hooks/auto-patchelf.sh;

  separateDebugInfo = makeSetupHook {
    name = "separate-debug-info-hook";
  } ./build-support/setup-hooks/separate-debug-info.sh;

  setupDebugInfoDirs = makeSetupHook {
    name = "setup-debug-info-dirs-hook";
  } ./build-support/setup-hooks/setup-debug-info-dirs.sh;

  strip-nondeterminism = perlPackages.strip-nondeterminism;
  stripJavaArchivesHook = makeSetupHook {
    name = "strip-java-archives-hook";
    propagatedBuildInputs = [ strip-nondeterminism ];
  } ./build-support/setup-hooks/strip-java-archives.sh;

  updateAutotoolsGnuConfigScriptsHook = makeSetupHook {
    name = "update-autotools-gnu-config-scripts-hook";
    substitutions = {
      gnu_config = gnu-config;
    };
  } ./build-support/setup-hooks/update-autotools-gnu-config-scripts.sh;

  readline70 = callPackage ./pkgs/readline/7.0.nix { };
  readline = callPackage ./pkgs/readline/8.3.nix { };

  util-linuxMinimal = util-linux.override {
    cryptsetupSupport = false;
    nlsSupport = false;
    ncursesSupport = false;
    pamSupport = false;
    shadowSupport = false;
    systemdSupport = false;
    translateManpages = false;
    withLastlog = false;
  };

  perlPackages = perl.pkgs;

  testers = callPackage ./build-support/testers { };

  texinfo6 = texinfo.v6;
  texinfo7 = texinfo.v7;
  texinfoInteractive = texinfo.interactive;

  # On non-GNU systems we need GNU Gettext for libintl.
  libintl = if stdenv.hostPlatform.libc != "glibc" then gettext else null;

  # libpng is auto-imported from pkgs-many/libpng/ via mkManyVariants
  # Variants: libpng.v1_2, libpng.v1_6 (default)
  libpng12 = prev.libpng.v1_2;

  genericUpdater = callPackage ./pkgs/common-updater-scripts/generic-updater.nix { };
  _experimental-update-script-combinators =
    callPackage ./pkgs/common-updater-scripts/combinators.nix
      { };
  directoryListingUpdater =
    callPackage ./pkgs/common-updater-scripts/directory-listing-updater.nix
      { };
  gitUpdater = callPackage ./pkgs/common-updater-scripts/git-updater.nix { };
  httpTwoLevelsUpdater = callPackage ./pkgs/common-updater-scripts/http-two-levels-updater.nix { };
  unstableGitUpdater = callPackage ./pkgs/common-updater-scripts/unstable-updater.nix { };

  libuuid = if stdenv.hostPlatform.isLinux then util-linuxMinimal else null;

  ncurses =
    if stdenv.hostPlatform.useiOSPrebuilt then
      null
    else if stdenv.hostPlatform.isDarwin then
      prev.ncurses.override {
        # ncurses is included in the SDK. Avoid an infinite recursion by using a bootstrap stdenv.
        stdenv = bootstrapStdenv;
      }
    else
      prev.ncurses;

  pkgconf = callPackage ./build-support/pkg-config-wrapper {
    pkg-config = pkgconf-unwrapped;
  };
  pkgconf-unwrapped = callPackage ./pkgs/pkgconf { };
  pkg-config = callPackage ./build-support/pkg-config-wrapper {
    pkg-config = pkg-config-unwrapped;
  };
  pkg-configUpstream = lib.lowPrio (
    pkg-config.override (old: {
      pkg-config = old.pkg-config.override {
        vanilla = true;
      };
    })
  );

  sqlite = lib.lowPrio (callPackage ./pkgs/sqlite { });
  sqlar = callPackage ./pkgs/sqlite/sqlar.nix { };
  sqlite-interactive = (sqlite.override { interactive = true; }).bin;

  gawk-with-extensions = callPackage ./pkgs/gawk/gawk-with-extensions.nix {
    extensions = gawkextlib.full;
  };
  gawkextlib = callPackage ./pkgs/gawk/gawkextlib.nix { };
  gawkInteractive = gawk.override { interactive = true; };

  tclPackages = tcl.pkgs;

  pam =
    if stdenv.hostPlatform.isLinux then
      linux-pam
    else if stdenv.hostPlatform.isFreeBSD then
      freebsd.libpam
    else
      openpam;

  systemd = callPackage ./pkgs/linux-support/pkgs/systemd {
    # break some cyclic dependencies
    util-linux = util-linuxMinimal;
    # provide a super minimal gnupg used for systemd-machined
    gnupg = gnupg.override {
      enableMinimal = true;
      guiSupport = false;
    };
  };
  systemdMinimal = systemd.override {
    pname = "systemd-minimal";
    withAcl = false;
    withAnalyze = false;
    withApparmor = false;
    withAudit = false;
    withCompression = false;
    withCoredump = false;
    withCryptsetup = false;
    withRepart = false;
    withDocumentation = false;
    withEfi = false;
    withFido2 = false;
    withGcrypt = false;
    withHostnamed = false;
    withHomed = false;
    withHwdb = false;
    withImportd = false;
    withLibBPF = false;
    withLibidn2 = false;
    withLocaled = false;
    withLogind = false;
    withMachined = false;
    withNetworkd = false;
    withNss = false;
    withOomd = false;
    withOpenSSL = false;
    withPCRE2 = false;
    withPam = false;
    withPolkit = false;
    withPortabled = false;
    withRemote = false;
    withResolved = false;
    withShellCompletions = false;
    withSysupdate = false;
    withSysusers = false;
    withTimedated = false;
    withTimesyncd = false;
    withTpm2Tss = false;
    withUserDb = false;
    withUkify = false;
    withBootloader = false;
    withPasswordQuality = false;
    withVmspawn = false;
    withQrencode = false;
    withLibarchive = false;
    withVConsole = false;
    # withKmod = false; # breaks udevCheckHook of bcache-tools
    withFirstboot = false;
    withKexectools = false;
    withLibseccomp = false;
    withNspawn = false;
  };
  systemdLibs = systemdMinimal.override {
    pname = "systemd-minimal-libs";
    buildLibsOnly = true;
  };
  # We do not want to include ukify in the normal systemd attribute as it
  # relies on Python at runtime.
  systemdUkify = systemd.override {
    pname = "systemd-ukify";
    withUkify = true;
  };
  udev = if lib.meta.availableOn stdenv.hostPlatform systemdLibs then systemdLibs else libudev-zero;

  inherit (callPackages ./pkgs/docbook-xsl { })
    docbook-xsl-nons # was docbook_xsl
    docbook-xsl-ns # was docbook-xsl-ns
    ;

  # Alias for compatibility
  docbook-xsl = docbook-xsl-nons;

  inherit (callPackage ./pkgs/libxml2 { })
    libxml2_13
    libxml2
    ;

  c-aresMinimal = callPackage ./pkgs/c-ares { withCMake = false; };

  libkrb5 = krb5; # TODO(de11n) Try to make krb5 reuse libkrb5 as a dependency

  ngtcp2-gnutls = callPackage ./pkgs/ngtcp2/gnutls.nix { };

  patchutils_0_3_3 = callPackage ./pkgs/patchutils/0.3.3.nix { };
  patchutils_0_4_2 = callPackage ./pkgs/patchutils/0.4.2.nix { };

  git = callPackage ./pkgs/git {
    perlLibs = [
      perlPackages.LWP
      perlPackages.URI
      perlPackages.TermReadKey
    ];
    smtpPerlLibs = [
      perlPackages.libnet
      perlPackages.NetSMTPSSL
      perlPackages.IOSocketSSL
      perlPackages.NetSSLeay
      perlPackages.AuthenSASL
      perlPackages.DigestHMAC
    ];
  };

  # The full-featured Git.
  gitFull = git.override {
    svnSupport = !stdenv.isCross && subversionClient != null;
    guiSupport = true;
    sendEmailSupport = !stdenv.isCross;
    withSsh = true;
    withLibsecret = !stdenv.hostPlatform.isDarwin;
  };

  git-doc = lib.addMetaAttrs {
    description = "Additional documentation for Git";
    longDescription = ''
      This package contains additional documentation (HTML and text files) that
      is referenced in the man pages of Git.
    '';
  } gitFull.doc;

  gitMinimal = git.override {
    withManual = false;
    osxkeychainSupport = false;
    pythonSupport = false;
    perlSupport = false;
    withpcre2 = false;
  };

  deterministic-host-uname = deterministic-uname.override {
    forPlatform = stdenv.targetPlatform; # offset by 1 so it works in nativeBuildInputs
  };

  makeFontsConf = callPackage ./build-support/make-fonts-conf { };
  glfw = glfw3;

  makeFontsCache = callPackage ./build-support/make-fonts-cache { };

  gtk3 = callPackage ./pkgs/gtk/3.x.nix {
    trackerSupport = false;
    cupsSupport = false;
    withIntrospection = false;
  };
  gtk4 = callPackage ./pkgs/gtk/4.x.nix { };

  buildcatrust = with python3.pkgs; toPythonApplication buildcatrust;

  docbook_sgml_dtd_31 = callPackage ./pkgs/docbook-sgml-dtd/3.1.nix { };
  docbook_sgml_dtd_41 = callPackage ./pkgs/docbook-sgml-dtd/4.1.nix { };

  docutils = with python3Packages; toPythonApplication docutils;

  opensshPackages = lib.dontRecurseIntoAttrs (callPackage ./pkgs/openssh { });
  openssh = opensshPackages.openssh.override {
    etcDir = "/etc/ssh";
  };
  opensshTest = openssh.tests.openssh;
  opensshWithKerberos = openssh.override {
    withKerberos = true;
  };
  openssh_hpn = opensshPackages.openssh_hpn.override {
    etcDir = "/etc/ssh";
  };
  openssh_hpnWithKerberos = openssh_hpn.override {
    withKerberos = true;
  };
  openssh_gssapi = opensshPackages.openssh_gssapi.override {
    etcDir = "/etc/ssh";
    withKerberos = true;
  };

  unixtools = lib.recurseIntoAttrs (callPackages ./unixtools.nix { });
  inherit (unixtools)
    hexdump
    ps
    logger
    eject
    umount
    mount
    wall
    hostname
    more
    sysctl
    getconf
    getent
    killall
    xxd
    watch
    ;

  sphinx = with python3.pkgs; toPythonApplication sphinx;

  # nixDependencies scope (moved to pkgs-many/nix/, top-level attr kept for splicing)
  nixDependencies = lib.recurseIntoAttrs (callPackage ./pkgs-many/nix/dependencies-scope.nix { });

  # nix is auto-imported from pkgs-many/nix/ via mkManyVariants
  # nix defaults to v2_34 (stable). Variants: nix.v2_28, ..., nix.v2_35, nix.git
  # Access individual components via nixVersions.nixComponents_2_34.nix-store, etc.

  nixStatic = pkgsStatic.nix;

  # Backwards-compatible nixVersions and nixComponents scopes for splicing.
  # The nixComponents_* attrs are constructed independently (not via nix.vX_Y.pkgs)
  # to avoid infinite recursion with the splice infrastructure.
  nixVersions =
    let
      addTestsShallowly =
        tests: pkg:
        pkg
        // {
          tests = pkg.tests // tests;
          passthru.tests = pkg.tests // tests;
        };
      addFallbackPathsCheck =
        pkg:
        addTestsShallowly {
          nix-fallback-paths =
            runCommand "test-nix-fallback-paths-version-equals-nix-stable"
              {
                paths = lib.concatStringsSep "\n" (
                  builtins.attrValues (import ./nixos/modules/installer/tools/nix-fallback-paths.nix)
                );
              }
              ''
                if [[ "" != $(grep -vE 'nix-([^-]*-)*${
                  lib.strings.replaceStrings [ "." ] [ "\\." ] pkg.version
                }$' <<< "$paths") ]]; then
                  echo "nix-fallback-paths not up to date with nixVersions.stable (nix-${pkg.version})"
                  echo "The following paths are not up to date:"
                  grep -v 'nix-${pkg.version}$' <<< "$paths"
                  echo
                  echo "Fix it by running:"
                  echo
                  echo "curl https://releases.nixos.org/nix/nix-${pkg.version}/fallback-paths.nix >nixos/modules/installer/tools/nix-fallback-paths.nix"
                  echo
                  exit 1
                else
                  echo "nix-fallback-paths versions up to date"
                  touch $out
                fi
              '';
        } pkg;

      # Nix >= 2.33 requires boost >= 1.87
      nixDependencies187 = nixDependencies.overrideScope (
        final: prev: {
          boost = pkgs.boost.v1_87;
        }
      );

      # Independently construct nixComponents scopes for splicing.
      # These must NOT go through nix.vX_Y.pkgs to avoid splice cycles.
      mkNixComponents =
        {
          version,
          src,
          deps,
          attrName,
        }:
        deps.callPackage ./pkgs-many/nix/modular/packages.nix {
          inherit version src;
          nixDependencies = deps;
          otherSplices = generateSplicesForMkScope [
            "nixVersions"
            attrName
          ];
        };

      nixComponentsArgs = {
        nixComponents_2_29 = {
          version = "2.29.4";
          src = fetchFromGitHub {
            owner = "NixOS";
            repo = "nix";
            tag = "2.29.4";
            hash = "sha256-eVELGOeQg37AZLu7xnsaW9VA4fBr3x1d97I0iAoIt8A=";
          };
          deps = nixDependencies;
          attrName = "nixComponents_2_29";
        };
        nixComponents_2_30 = {
          version = "2.30.5";
          src = fetchFromGitHub {
            owner = "NixOS";
            repo = "nix";
            tag = "2.30.5";
            hash = "sha256-tGiV71RxtCNcUNX86ZwmOIghG4pLwm5nlRKd89er7Gk=";
          };
          deps = nixDependencies;
          attrName = "nixComponents_2_30";
        };
        nixComponents_2_31 = {
          version = "2.31.5";
          src = fetchFromGitHub {
            owner = "NixOS";
            repo = "nix";
            tag = "2.31.5";
            hash = "sha256-b7fhCXxl9qKTNPQvG8T/+nOxB95kalt9/aSY+ZSRctk=";
          };
          deps = nixDependencies;
          attrName = "nixComponents_2_31";
        };
        nixComponents_2_32 = {
          version = "2.32.8";
          src = fetchFromGitHub {
            owner = "NixOS";
            repo = "nix";
            tag = "2.32.8";
            hash = "sha256-vj5o3dP9QaiW025a5INgg9j9XwScFsCYr6WrBxqSvUk=";
          };
          deps = nixDependencies;
          attrName = "nixComponents_2_32";
        };
        nixComponents_2_33 = {
          version = "2.33.6";
          src = fetchFromGitHub {
            owner = "NixOS";
            repo = "nix";
            tag = "2.33.6";
            hash = "sha256-I3A0vFSFg3iI8tGBuQlAy7DzcxYcG39b06rfKOzGRvc=";
          };
          deps = nixDependencies187;
          attrName = "nixComponents_2_33";
        };
        nixComponents_2_34 = {
          version = "2.34.8";
          src = fetchFromGitHub {
            owner = "NixOS";
            repo = "nix";
            tag = "2.34.8";
            hash = "sha256-Rvy1PmIUMGI0IS/kwDwmf/VrorU8v1iZYejssSVu1rY=";
          };
          deps = nixDependencies187;
          attrName = "nixComponents_2_34";
        };
        nixComponents_2_35 = {
          version = "2.35.2";
          src = fetchFromGitHub {
            owner = "NixOS";
            repo = "nix";
            tag = "2.35.2";
            hash = "sha256-C/YEm/5IPiAMxQH5aHlkwgQMkLqK7NVsudEWdlzBZAA=";
          };
          deps = nixDependencies187;
          attrName = "nixComponents_2_35";
        };
        nixComponents_git = {
          version = "2.36pre20260825_3aef07e8";
          src = fetchFromGitHub {
            owner = "NixOS";
            repo = "nix";
            rev = "3aef07e8fe2dc4b226515ecd536b3002c93577c7";
            hash = "sha256-78tbhNekla4TxDb1FEzt6kPybcoueszGFpjqC1CuLBU=";
          };
          deps = nixDependencies187;
          attrName = "nixComponents_git";
        };
      };
    in
    lib.recurseIntoAttrs (
      {
        nix_2_28 = nix.v2_28;
        nix_2_29 = nix.v2_29;
        nix_2_30 = nix.v2_30;
        nix_2_31 = nix.v2_31;
        nix_2_32 = nix.v2_32;
        nix_2_33 = nix.v2_33;
        nix_2_34 = nix.v2_34;
        nix_2_35 = nix.v2_35;
        inherit (nix) git;
        latest = nix.v2_35;
        stable = addFallbackPathsCheck nix;
      }
      // builtins.mapAttrs (_name: args: mkNixComponents args) nixComponentsArgs
    );

  ensureNewerSourcesHook =
    { year }:
    makeSetupHook
      {
        name = "ensure-newer-sources-hook";
      }
      (
        writeScript "ensure-newer-sources-hook.sh" ''
          postUnpackHooks+=(_ensureNewerSources)
          _ensureNewerSources() {
            local r=$sourceRoot
            # Avoid passing option-looking directory to find. The example is diffoscope-269:
            #   https://salsa.debian.org/reproducible-builds/diffoscope/-/issues/378
            [[ $r == -* ]] && r="./$r"
            '${findutils}/bin/find' "$r" \
              '!' -newermt '${year}-01-01' -exec touch -h -d '${year}-01-02' '{}' '+'
          }
        ''
      );
  # Zip file format only allows times after year 1980, which makes e.g. Python
  # wheel building fail with:
  # ValueError: ZIP does not support timestamps before 1980
  ensureNewerSourcesForZipFilesHook = ensureNewerSourcesHook { year = "1980"; };

  libclang = llvmPackages.libclang;
  clang-manpages = llvmPackages.clang-manpages;
  clang = llvmPackages.clang;
  clang-tools = llvmPackages.clang-tools;
  clangStdenv = if stdenv.cc.isClang then stdenv else lib.lowPrio llvmPackages.stdenv;
  libcxxStdenv =
    if stdenv.hostPlatform.isDarwin then stdenv else lib.lowPrio llvmPackages.libcxxStdenv;

  # TODO: fix this properly
  # LLVM is auto-imported from pkgs-many/llvm via mkManyVariants
  # llvm defaults to v21 as the LLVM library
  # llvm.pkgs provides the full package scope (clang, lld, lldb, etc.)
  # Individual versions accessible as: llvm.v18, llvm.v19, etc.
  # Package scopes accessible as: llvm.v18.pkgs, llvm.v19.pkgs, etc.
  # Old names like llvmPackages_18, clang_18, etc. are available via stdenv/aliases.nix

  llvmPackages = if stdenv.hostPlatform.isDarwin then llvmPackages_21 else llvm.pkgs;
  llvm =
    if stdenv.hostPlatform.isDarwin then
      lib.makeOverridable (lib.mirrorFunctionArgs prev.llvm.override (
        args:
        let
          scope = if args == { } then llvmPackages else llvmPackages.override args;
        in
        lib.fix (
          llvmPackage:
          scope.llvm.overrideAttrs (old: {
            passthru =
              old.passthru or { }
              // prev.llvm.variants
              // {
                inherit (prev.llvm) extendVariants variantArgs;
                pkgs = scope;
                v21 = llvmPackage;
                variants = prev.llvm.variants // {
                  v21 = llvmPackage;
                };
              };
          })
        )
      )) { }
    else
      prev.llvm;

  # Splicing needs the scopes before LLVM derivations can select their
  # dependencies. Construct them directly for cross toolchains to avoid a cycle.
  # Native scopes retain the variant package interface.
  llvmPackages_18 =
    if
      stdenv.buildPlatform != stdenv.targetPlatform
      && (stdenv.buildPlatform.isDarwin || stdenv.targetPlatform.isDarwin)
    then
      callPackage (import ./pkgs-many/llvm/scope.nix (import ./pkgs-many/llvm/variants.nix).v18) { }
    else
      prev.llvm.v18.pkgs;
  llvmPackages_19 =
    if
      stdenv.buildPlatform != stdenv.targetPlatform
      && (stdenv.buildPlatform.isDarwin || stdenv.targetPlatform.isDarwin)
    then
      callPackage (import ./pkgs-many/llvm/scope.nix (import ./pkgs-many/llvm/variants.nix).v19) { }
    else
      prev.llvm.v19.pkgs;
  llvmPackages_20 =
    if
      stdenv.buildPlatform != stdenv.targetPlatform
      && (stdenv.buildPlatform.isDarwin || stdenv.targetPlatform.isDarwin)
    then
      callPackage (import ./pkgs-many/llvm/scope.nix (import ./pkgs-many/llvm/variants.nix).v20) { }
    else
      prev.llvm.v20.pkgs;
  llvmPackages_21 =
    if
      stdenv.buildPlatform != stdenv.targetPlatform
      && (stdenv.buildPlatform.isDarwin || stdenv.targetPlatform.isDarwin)
    then
      callPackage (import ./pkgs-many/llvm/scope.nix (import ./pkgs-many/llvm/variants.nix).v21) { }
    else
      prev.llvm.v21.pkgs;
  llvmPackages_git =
    if
      stdenv.buildPlatform != stdenv.targetPlatform
      && (stdenv.buildPlatform.isDarwin || stdenv.targetPlatform.isDarwin)
    then
      callPackage (import ./pkgs-many/llvm/scope.nix (import ./pkgs-many/llvm/variants.nix).git) { }
    else
      prev.llvm.git.pkgs;

  # Common LLVM packages from the default version
  lld = llvmPackages.lld;
  lldb = llvmPackages.lldb;
  flang = llvm.v20.pkgs.flang;
  libclc = llvmPackages.libclc;
  libllvm = llvmPackages.libllvm;
  llvm-manpages = llvmPackages.llvm-manpages;

  # Lua is auto-imported from pkgs-many/lua via mkManyVariants
  # lua defaults to v5_4 (Lua 5.4.7) as the Lua interpreter
  # lua.pkgs provides the full Lua package scope (awesome-wm-widgets, etc.)
  # Individual versions accessible as: lua.v5_1, lua.v5_2, lua.v5_3, lua.v5_4, lua.v5_5
  # LuaJIT variants accessible as: lua.luajit_2_0, lua.luajit_2_1, lua.luajit_openresty
  # Package scopes accessible as: lua.v5_3.pkgs, lua.luajit_2_0.pkgs, etc.

  luaPackages = lua.pkgs;
  luajitPackages = lua.luajit_2_1.pkgs;

  asciidoc = callPackage ./pkgs/asciidoc {
    inherit (python3.pkgs)
      pygments
      matplotlib
      numpy
      aafigure
      recursive-pth-loader
      ;
  };
  # TODO(corepkgs): requires graphviz, lilypond, imagemagick, etc.
  asciidoc-full = throw "asciidoc-full: standard features require graphviz, lilypond, and other packages not yet in core-pkgs";
  asciidoc-full-with-plugins = throw "asciidoc-full-with-plugins: requires packages not yet in core-pkgs";

  imagemagick6_light = imagemagick6.override {
    bzip2Support = false;
    zlibSupport = false;
    libX11Support = false;
    libXtSupport = false;
    fontconfigSupport = false;
    freetypeSupport = false;
    ghostscriptSupport = false;
    libjpegSupport = false;
    djvulibreSupport = false;
    lcms2Support = false;
    openexrSupport = false;
    libpngSupport = false;
    liblqr1Support = false;
    librsvgSupport = false;
    libtiffSupport = false;
    libxml2Support = false;
    openjpegSupport = false;
    libwebpSupport = false;
    libheifSupport = false;
    libde265Support = false;
  };
  imagemagick6 = callPackage ./pkgs/imagemagick/6.x.nix { };
  imagemagick6Big = imagemagick6.override {
    ghostscriptSupport = true;
  };
  imagemagick_light = imagemagick.override {
    bzip2Support = false;
    zlibSupport = false;
    libX11Support = false;
    libXtSupport = false;
    fontconfigSupport = false;
    freetypeSupport = false;
    libraqmSupport = false;
    ghostscriptSupport = false;
    libjpegSupport = false;
    djvulibreSupport = false;
    lcms2Support = false;
    openexrSupport = false;
    libpngSupport = false;
    liblqr1Support = false;
    librsvgSupport = false;
    libtiffSupport = false;
    libxml2Support = false;
    openjpegSupport = false;
    libwebpSupport = false;
    libheifSupport = false;
    libjxlSupport = false;
  };
  imagemagickBig = imagemagick.override {
    ghostscriptSupport = true;
  };

  inherit (texlive.schemes)
    texliveBasic
    texliveBookPub
    texliveConTeXt
    texliveFull
    texliveGUST
    texliveInfraOnly
    texliveMedium
    texliveMinimal
    texliveSmall
    texliveTeTeX
    ;
  texlivePackages = lib.recurseIntoAttrs (lib.mapAttrs (_: v: v.build) texlive.pkgs);

  validatePkgConfig = makeSetupHook {
    name = "validate-pkg-config";
    propagatedBuildInputs = [
      findutils
      pkg-config
    ];
  } ./build-support/setup-hooks/validate-pkg-config.sh;

  wrapRustcWith = { rustc-unwrapped, ... }@args: callPackage ./build-support/rust/rustc-wrapper args;
  wrapRustc = rustc-unwrapped: wrapRustcWith { inherit rustc-unwrapped; };

  # Rust is auto-imported from pkgs-many/rust via mkManyVariants
  # Individual versions: rust.v1_91, rust.v1_98, etc.
  # Package scopes: rust.pkgs, rust.v1_91.pkgs, etc.
  rustPackages = rust.pkgs;

  inherit (rustPackages)
    cargo
    cargo-auditable
    cargo-auditable-cargo-wrapper
    clippy
    rustc
    rustc-unwrapped
    rustPlatform
    rustfmt
    ;

  makeRustPlatform = callPackage ./pkgs/rust/make-rust-platform.nix { };

  buildRustCrate =
    let
      # Returns a true if the builder's rustc was built with support for the target.
      targetAlreadyIncluded = lib.elem stdenv.hostPlatform.rust.rustcTarget (
        lib.splitString "," (
          lib.removePrefix "--target=" (
            lib.elemAt (lib.filter (
              f: lib.hasPrefix "--target=" f
            ) pkgsBuildBuild.rustc.unwrapped.configureFlags) 0
          )
        )
      );
    in
    callPackage ./build-support/rust/build-rust-crate (
      { }
      // lib.optionalAttrs (stdenv.hostPlatform.libc == null) {
        stdenv = stdenvNoCC; # Some build targets without libc will fail to evaluate with a normal stdenv.
      }
      // lib.optionalAttrs targetAlreadyIncluded { inherit (pkgsBuildBuild) rustc cargo; } # Optimization.
    );
  buildRustCrateHelpers = callPackage ./build-support/rust/build-rust-crate/helpers.nix { };

  defaultCrateOverrides = callPackage ./build-support/rust/default-crate-overrides.nix { };

  inherit (callPackages ./pkgs/cargo-pgrx { })
    cargo-pgrx_0_12_0_alpha_1
    cargo-pgrx_0_12_6
    cargo-pgrx_0_16_0
    cargo-pgrx_0_16_1
    cargo-pgrx
    ;

  buildPgrxExtension = callPackage ./pkgs/cargo-pgrx/buildPgrxExtension.nix { };

  rust-bindgen-unwrapped = callPackage ./pkgs/rust-bindgen/unwrapped.nix { };
  rustup-toolchain-install-master = callPackage ./pkgs/rustup-toolchain-install-master { };

  writableTmpDirAsHomeHook = callPackage (
    { makeSetupHook }:
    makeSetupHook {
      name = "writable-tmpdir-as-home-hook";
    } ./build-support/setup-hooks/writable-tmpdir-as-home.sh
  ) { };

  writers = callPackage ./build-support/writers { };
  # TODO(corepkgs): gixy requires packages not yet in core-pkgs (writeNginxConfig validation)
  gixy = null;

  buildDotnetModule = callPackage ./build-support/dotnet/build-dotnet-module { };
  mkNugetDeps = null; # TODO(corepkgs): implement NuGet dependency fetcher
  mkNugetSource = null; # TODO(corepkgs): implement NuGet source builder

  appimageTools = callPackage ./build-support/appimage { };

  buildFHSEnv = buildFHSEnvBubblewrap;
  buildFHSEnvChroot = callPackage ./build-support/build-fhsenv-chroot { }; # Deprecated; use buildFHSEnv/buildFHSEnvBubblewrap
  buildFHSEnvBubblewrap = callPackage ./build-support/build-fhsenv-bubblewrap { };

  uboot = callFromScope ./pkgs/uboot { };
  inherit (uboot) buildUBoot;

  inherit (arm-trusted-firmware) buildArmTrustedFirmware;
}

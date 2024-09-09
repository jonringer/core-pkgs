# This a top-level overlay which is applied after this "autoCalled" pkgs directory.
# This mainly serves as a way to define attrs at the top-level of pkgs which
# require more than just passing default arguments to nix expressions

final: prev: with final; let
  inherit (final.lib) recurseIntoAttrs;
in {

  c-aresMinimal = callPackage ./pkgs/c-ares { withCMake = false; };

  cmakeMinimal = prev.cmake.override { isMinimalBuild = true; };

  curlMinimal = prev.curl;

  curl = curlMinimal.override ({
    idnSupport = true;
    pslSupport = true;
    zstdSupport = true;
  } // lib.optionalAttrs (!stdenv.hostPlatform.isStatic) {
    brotliSupport = true;
  });

  # TODO: support darwin builds
  darwin = {
    autoSignDarwinBinariesHook = null;
    bootstrap_cmds = null;
    signingUtils = null;
    configd = null;
  };

  db_4 = callPackage ./pkgs/db/db-4.8.nix { };

  docbook_xml_dtd_412 = callPackage ./pkgs/docbook-xml-dtd/4.1.2.nix { };

  docbook_xml_dtd_43 = callPackage ./pkgs/docbook-xml-dtd/4.3.nix { };

  docbook_xml_dtd_44 = callPackage ./pkgs/docbook-xml-dtd/4.4.nix { };

  docbook_xml_dtd_45 = callPackage ./pkgs/docbook-xml-dtd/4.5.nix { };

  docbook_xml_ebnf_dtd = callPackage ./pkgs/docbook-xml-dtd/docbook-ebnf { };

  inherit (callPackage ./pkgs/docbook_xsl { })
    docbook-xsl-nons
    docbook-xsl-ns
    ;

  # TODO: move this to aliases
  docbook_xsl = docbook-xsl-nons;
  docbook_xsl_ns = docbook-xsl-ns;

  fetchgit = (callPackage ./build-support/fetchgit {
    git = buildPackages.gitMinimal;
    cacert = buildPackages.cacert;
    git-lfs = buildPackages.git-lfs;
  }) // { # fetchgit is a function, so we use // instead of passthru.
    tests = pkgs.tests.fetchgit;
  };

  fetchFromGitLab = callPackage ./build-support/fetchgitlab { };

  fetchpatch = callPackage ./build-support/fetchpatch {
    # 0.3.4 would change hashes: https://github.com/NixOS/nixpkgs/issues/25154
    patchutils = __splicedPackages.patchutils_0_3_3;
  } // {
    tests = pkgs.tests.fetchpatch;
    version = 1;
  };

  fetchpatch2 = callPackage ../build-support/fetchpatch {
    patchutils = __splicedPackages.patchutils_0_4_2;
  } // {
    tests = pkgs.tests.fetchpatch2;
    version = 2;
  };

  # `fetchurl' downloads a file from the network.
  fetchurl =
    if stdenv.isCross
    then buildPackages.fetchurl # No need to do special overrides twice,
    else
      lib.makeOverridable (import ./build-support/fetchurl) {
        inherit lib stdenvNoCC buildPackages;
        inherit cacert;
        curl = buildPackages.curlMinimal.override (old: rec {
          # break dependency cycles
          fetchurl = stdenv.fetchurlBoot;
          zlib = buildPackages.zlib.override { fetchurl = stdenv.fetchurlBoot; };
          pkg-config = buildPackages.pkg-config.override (old: {
            pkg-config-unwrapped = old.pkg-config-unwrapped.override {
              inherit fetchurl;
            };
          });
          perl = buildPackages.perl.override { inherit zlib; fetchurl = stdenv.fetchurlBoot; };
          openssl = buildPackages.openssl.override {
            fetchurl = stdenv.fetchurlBoot;
            buildPackages = {
              coreutils = buildPackages.coreutils.override {
                fetchurl = stdenv.fetchurlBoot;
                inherit perl;
                xz = buildPackages.xz.override { fetchurl = stdenv.fetchurlBoot; };
                gmpSupport = false;
                aclSupport = false;
                attrSupport = false;
              };
              inherit perl;
            };
            inherit perl;
          };
          libssh2 = buildPackages.libssh2.override {
            fetchurl = stdenv.fetchurlBoot;
            inherit zlib openssl;
          };
          # On darwin, libkrb5 needs bootstrap_cmds which would require
          # converting many packages to fetchurl_boot to avoid evaluation cycles.
          # So turn gssSupport off there, and on Windows.
          # On other platforms, keep the previous value.
          gssSupport =
            if stdenv.isDarwin || stdenv.hostPlatform.isWindows
            then false
            else old.gssSupport or true; # `? true` is the default
          libkrb5 = buildPackages.libkrb5.override {
            fetchurl = stdenv.fetchurlBoot;
            inherit pkg-config perl openssl;
            keyutils = buildPackages.keyutils.override { fetchurl = stdenv.fetchurlBoot; };
          };
          nghttp2 = buildPackages.nghttp2.override {
            fetchurl = stdenv.fetchurlBoot;
            inherit pkg-config;
            enableApp = false; # curl just needs libnghttp2
            enableTests = false; # avoids bringing `cunit` and `tzdata` into scope
          };
        });
      };

   fetchzip = callPackage ./build-support/fetchzip { } // {
     tests = pkgs.tests.fetchzip;
   };


  findXMLCatalogs = makeSetupHook {
    name = "find-xml-catalogs-hook";
  } ./build-support/setup-hooks/find-xml-catalogs.sh;

  fuse_2 = prev.fuse.fuse_2;
  fuse_3 = prev.fuse.fuse_3;
  fuse = prev.fuse.fuse_3;

  # TODO: Move this into an "updaters.*" package set
  genericUpdater = prev.generic-updater;
  gitUpdater = prev.git-updater;

  git = callPackage ./pkgs/git {
    perlLibs = [perlPackages.LWP perlPackages.URI perlPackages.TermReadKey];
    smtpPerlLibs = [
      perlPackages.libnet perlPackages.NetSMTPSSL
      perlPackages.IOSocketSSL perlPackages.NetSSLeay
      perlPackages.AuthenSASL perlPackages.DigestHMAC
    ];
  };

  # The full-featured Git.
  gitFull = git.override {
    svnSupport = true;
    guiSupport = true;
    sendEmailSupport = true;
    withSsh = true;
    withLibsecret = !stdenv.isDarwin;
  };


  glibcLocalesUtf8 = prev.glibcLocales.override { allLocales = false; };

  gpm_ncurses = gpm.override { withNcurses = true; };

  grpc = null;

  installShellFiles = callPackage ./build-support/install-shell-files { };

  # TODO: core-pkgs: move openGL into it's own file
  ## libGL/libGLU/Mesa stuff

  # Default libGL implementation.
  #
  # Android NDK provides an OpenGL implementation, we can just use that.
  #
  # On macOS, we use the OpenGL framework. Packages that still need GLX
  # specifically can pull in libGLX instead. If you have a package that
  # should work without X11 but it can’t find the library, it may help
  # to add the path to `NIX_CFLAGS_COMPILE`:
  #
  #     -L${libGL}/Library/Frameworks/OpenGL.framework/Versions/Current/Libraries
  #
  # If you still can’t get it working, please don’t hesitate to ping
  # @NixOS/darwin-maintainers to ask an expert to take a look.
  libGL =
    if stdenv.hostPlatform.useAndroidPrebuilt then
      stdenv
    else if stdenv.hostPlatform.isDarwin then
      darwin.apple_sdk.frameworks.OpenGL
    else
      libglvnd;

  # On macOS, we use the OpenGL framework. Packages that use libGLX on
  # macOS may need to depend on mesa_glu directly if this doesn’t work.
  libGLU =
    if stdenv.hostPlatform.isDarwin then
      darwin.apple_sdk.frameworks.OpenGL
    else
      mesa_glu;

  # libglvnd does not work (yet?) on macOS.
  libGLX =
    if stdenv.hostPlatform.isDarwin then
      mesa
    else
      libglvnd;

  # On macOS, we use the GLUT framework. Packages that use libGLX on
  # macOS may need to depend on freeglut directly if this doesn’t work.
  libglut =
    if stdenv.hostPlatform.isDarwin then
      darwin.apple_sdk.frameworks.GLUT
    else
      freeglut;

  # TODO: core-pkg: Add darwin support
  # mesa = if stdenv.isDarwin
  #   then darwin.apple_sdk_11_0.callPackage ../development/libraries/mesa/darwin.nix {
  #     inherit (darwin.apple_sdk_11_0.libs) Xplugin;
  #   }
  #   else callPackage ../development/libraries/mesa {};


  libcap_ng = callPackage ./os-specific/linux/libcap-ng { };

  # TODO: fix this
  libkrb5 = prev.krb5.override { type = "lib"; };

  libsoup_3 = callPackage ./pkgs/libsoup/3.x.nix { };

  linux-pam = pam;

  memstreamHook = makeSetupHook {
    name = "memstream-hook";
    propagatedBuildInputs = [ memstream ];
  } ./pkgs/memstream/setup-hook.sh;

  # TOOD: support NixOS tests
  nixosTests = { };

  opensshPackages = dontRecurseIntoAttrs (callPackage ./pkgs/openssh {});

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

  openssl = openssl_3;
  inherit (callPackages ./pkgs/openssl { })
    openssl_1_1
    openssl_3
    openssl_3_2
    openssl_3_3
    ;

  patchutils_0_3_3 = callPackage ./pkgs/patchutils/0.3.3.nix { };

  patchutils_0_4_2 = callPackage ./pkgs/patchutils/0.4.2.nix { };

  perlInterpreters = callPackage ./pkgs/perl { };
  perl = perlInterpreters.perl538;
  perlPackages = perl.pkgs;

  pkg-config = callPackage ./build-support/pkg-config-wrapper { };

  procps = if stdenv.isLinux
    then callPackage ./os-specific/linux/procps-ng { }
    else throw "non-linux procps is not supported yet";

  inherit (callPackage ./python { })
    python310
    python311
    python312
    pypy
    ;
  python = python3;
  python3 = python311;

  removeReferencesTo = callPackage ./build-support/remove-references-to {
    inherit (darwin) signingUtils;
  };

  shortenPerlShebang = makeSetupHook {
    name = "shorten-perl-shebang-hook";
    propagatedBuildInputs = [ dieHook ];
  } ./build-support/setup-hooks/shorten-perl-shebang.sh;

  substitute = callPackage ./build-support/substitute/substitute.nix { };

  substituteAll = callPackage ./build-support/substitute/substitute-all.nix { };

  substituteAllFiles = callPackage ./build-support/substitute-files/substitute-all-files.nix { };

  swig_3 = prev.swig;
  swig_4 = callPackage ./pkgs/swig/4.nix { };

  tcl = tcl_8_6;
  tcl_8_6 = callPackage ./pkgs/tcl/8.6.nix { };
  tcl_8_5 = callPackage ./pkgs/tcl/8.5.nix { };

  tk = tcl_8_6;
  tk_8_6 = callPackage ./pkgs/tk/8.6.nix { };
  tk_8_5 = callPackage ./pkgs/tk/8.5.nix { tcl = tcl_8_5; };

  libxcrypt = prev.libxcrypt.override {
    # Prevent infinite recursion
    fetchurl = stdenv.fetchurlBoot;
    perl = buildPackages.perl.override {
      enableCrypt = false;
      fetchurl = stdenv.fetchurlBoot;
    };
  };

  util-linuxMinimal = util-linux.override {
    nlsSupport = false;
    ncursesSupport = false;
    systemdSupport = false;
    translateManpages = false;
  };

  xorg = let
    # Use `lib.callPackageWith __splicedPackages` rather than plain `callPackage`
    # so as not to have the newly bound xorg items already in scope,  which would
    # have created a cycle.
    overrides = lib.callPackageWith __splicedPackages ./pkgs/xorg/overrides.nix {
      # TODO: core-pkgs: support dawrin
      # inherit (darwin.apple_sdk.frameworks) ApplicationServices Carbon Cocoa;
      # inherit (darwin.apple_sdk.libs) Xplugin;
      # inherit (buildPackages.darwin) bootstrap_cmds;
      udev = if stdenv.isLinux then udev else null;
      libdrm = if stdenv.isLinux then libdrm else null;
    };

    # TODO: core-pkgs: Move xorg's generated to a generated.nix, and move the package set
    # logic into a default.nix
    generatedPackages = lib.callPackageWith __splicedPackages ./pkgs/xorg { };

    xorgPackages = makeScopeWithSplicing' {
      otherSplices = generateSplicesForMkScope "xorg";
      f = lib.extends overrides generatedPackages;
    };

  in recurseIntoAttrs xorgPackages;


  inherit (xorg)
    libX11
    xorgproto
    ;

  # Support windows
  windows = {
    mingw_w64 = null;
  };
}

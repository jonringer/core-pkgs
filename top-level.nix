# This a top-level overlay which is applied after this "autoCalled" pkgs directory.
# This mainly serves as a way to define attrs at the top-level of pkgs which
# require more than just passing default arguments to nix expressions

final: prev: with final; let
  lib = prev.lib;
in
{
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
  };

  db_4 = callPackage ./pkgs/db/db-4.8.nix { };

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

  glibcLocalesUtf8 = prev.glibcLocales.override { allLocales = false; };

  gpm_ncurses = gpm.override { withNcurses = true; };

  grpc = null;

  installShellFiles = callPackage ./build-support/install-shell-files { };

  libcap_ng = callPackage ./os-specific/linux/libcap-ng { };

  # TODO: fix this
  libkrb5 = prev.krb5.override { type = "lib"; };

  libsoup_3 = callPackage ./pkgs/libsoup/3.x.nix { };

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

  pkg-config = callPackage ./build-support/pkg-config-wrapper { };

  procps = if stdenv.isLinux
    then callPackage ./os-specific/linux/procps-ng { }
    else throw "non-linux procps is not supported yet";

  removeReferencesTo = callPackage ./build-support/remove-references-to {
    inherit (darwin) signingUtils;
  };

  substitute = callPackage ./build-support/substitute/substitute.nix { };

  substituteAll = callPackage ./build-support/substitute/substitute-all.nix { };

  substituteAllFiles = callPackage ./build-support/substitute-files/substitute-all-files.nix { };

  swig_3 = prev.swig;
  swig_4 = callPackage ./pkgs/swig/4.nix { };

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

  # Support windows
  windows = {
    mingw_w64 = null;
  };
}

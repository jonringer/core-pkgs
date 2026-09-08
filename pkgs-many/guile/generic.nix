{
  version,
  src-hash,
  setupHook,
  packageAtLeast,
  packageOlder,
  packageBetween,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  fetchpatch,
  buildPackages,
  coverageAnalysis ? null,
  gawk,
  gmp,
  libtool,
  makeWrapper,
  pkg-config,
  pkgsBuildBuild,
  readline,
  # 2.0+ dependencies
  boehmgc ? null,
  libffi ? null,
  libunistring ? null,
  # 3.0+ dependencies
  libxcrypt ? null,
  autoreconfHook ? null,
  writeScript ? null,
}:

let
  # Do either a coverage analysis build or a standard build (2.0+ only)
  builder =
    if packageAtLeast "2.0" && coverageAnalysis != null then coverageAnalysis else stdenv.mkDerivation;

  # Major.minor version for versioned paths
  majorMinor = lib.versions.majorMinor version;

  # Compute source URL extension based on version
  srcExtension = if packageOlder "2.0" then "tar.gz" else "tar.xz";
in
builder (
  rec {
    pname = "guile";
    inherit version;

    src = fetchurl {
      url = "mirror://gnu/${pname}/${pname}-${version}.${srcExtension}";
      hash = src-hash;
    };

    outputs = [
      "out"
      "dev"
      "info"
    ];
    setOutputFlags = false; # $dev gets into the library otherwise

    # Version-specific configure flags
    configureFlags =
      (lib.optionals (packageOlder "2.0") [
        # GCC 4.6 raises a number of set-but-unused warnings.
        "--disable-error-on-warning"
      ])
      ++ (lib.optionals (packageAtLeast "2.0" && packageOlder "2.2") [
        "--with-libreadline-prefix"
      ])
      ++ (lib.optionals (packageAtLeast "2.2") [
        "--with-libreadline-prefix=${lib.getDev readline}"
      ])
      # Guile needs patching to preset results for the configure tests about
      # pthreads, which work only in native builds.
      ++ lib.optional (stdenv.hostPlatform != stdenv.buildPlatform) "--with-threads=no"
      ++ lib.optionals stdenv.hostPlatform.isSunOS [
        # Make sure the right <gmp.h> is found, and not the incompatible
        # /usr/include/mp.h from OpenSolaris. See
        # <https://lists.gnu.org/archive/html/hydra-users/2012-08/msg00000.html>
        # for details.
        "--with-libgmp-prefix=${lib.getDev gmp}"

        # Same for these (?).
      ]
      ++ lib.optionals (packageAtLeast "2.0" && stdenv.hostPlatform.isSunOS) [
        "--with-libreadline-prefix=${lib.getDev readline}"
        "--with-libunistring-prefix=${libunistring}"

        # See below.
        "--without-threads"
      ]
      # '-flto' autodetection is not correct: https://github.com/NixOS/nixpkgs/pull/160051#issuecomment-1046193028
      ++ lib.optional (packageAtLeast "3.0" && stdenv.hostPlatform.isDarwin) "--disable-lto";

    depsBuildBuild = [
      buildPackages.stdenv.cc
    ]
    ++ lib.optional (stdenv.hostPlatform != stdenv.buildPlatform) (
      if packageOlder "2.0" then
        pkgsBuildBuild.guile.v1_8
      else if packageOlder "2.2" then
        pkgsBuildBuild.guile.v2_0
      else if packageOlder "3.0" then
        pkgsBuildBuild.guile.v2_2
      else
        pkgsBuildBuild.guile.v3_0
    );

    nativeBuildInputs = [
      makeWrapper
      pkg-config
    ]
    ++ lib.optional (
      packageAtLeast "3.0" && !lib.systems.equals stdenv.hostPlatform stdenv.buildPlatform
    ) autoreconfHook;

    buildInputs =
      (lib.optionals (packageOlder "2.0") [
        libtool
        readline
      ])
      ++ (lib.optionals (packageAtLeast "2.0") [
        readline
        libtool
        libunistring
        libffi
      ])
      ++ lib.optionals (packageAtLeast "3.0" && stdenv.hostPlatform.isLinux) [ libxcrypt ];

    propagatedBuildInputs =
      (lib.optionals (packageOlder "2.0") [
        gmp

        # XXX: These ones aren't normally needed here, but `libguile*.la' has '-l'
        # flags for them without corresponding '-L' flags. Adding them here will add
        # the needed `-L' flags.  As for why the `.la' file lacks the `-L' flags,
        # see below.
        libtool
      ])
      ++ (lib.optionals (packageAtLeast "2.0") [
        boehmgc
        gmp

        # These ones aren't normally needed here, but `libguile*.la' has '-l'
        # flags for them without corresponding '-L' flags. Adding them here will
        # add the needed `-L' flags.  As for why the `.la' file lacks the `-L'
        # flags, see below.
        libtool
        libunistring
      ])
      ++ lib.optionals (packageAtLeast "3.0" && stdenv.hostPlatform.isLinux) [ libxcrypt ];

    strictDeps = lib.optional (packageAtLeast "3.0") true;

    # Reproducibility is affected
    enableParallelBuilding = false;

    patches =
      # 1.8 only patches
      lib.optionals (packageOlder "2.0") [
        ./patches/1.8/cpp-4.5.patch
        ./patches/1.8/CVE-2016-8605.patch
      ]
      # 2.0 only patches
      ++ lib.optionals (packageBetween "2.0" "2.2") [
        ./patches/2.0/clang.patch
        ./patches/2.0/disable-gc-sensitive-tests.patch
        ./patches/2.0/riscv.patch
        ./patches/2.0/filter-mkostemp-darwin.patch
      ]
      # 2.0+ patches
      ++ lib.optionals (packageAtLeast "2.0") [ ./patches/common/eai_system.patch ]
      # Coverage analysis patches (conditional on coverageAnalysis parameter)
      ++ lib.optional (packageAtLeast "2.0" && coverageAnalysis != null) (
        if packageOlder "2.2" then
          ./patches/2.0/gcov-file-name.patch
        else if packageOlder "3.0" then
          ./patches/2.2/gcov-file-name.patch
        else
          ./patches/3.0/gcov-file-name.patch
      )
      # 2.0 only fetchpatch for stability
      ++ lib.optionals (packageBetween "2.0" "2.2") [
        # Fixes stability issues with 00-repl-server.test
        (fetchpatch {
          url = "https://git.savannah.gnu.org/cgit/guile.git/patch/?id=2fbde7f02adb8c6585e9baf6e293ee49cd23d4c4";
          sha256 = "0p6c1lmw1iniq03z7x5m65kg3lq543kgvdb4nrxsaxjqf3zhl77v";
        })
      ]
      # 2.0+ Darwin-specific fetchpatch
      ++ lib.optionals (packageAtLeast "2.0" && stdenv.hostPlatform.isDarwin) [
        (fetchpatch {
          url = "https://gitlab.gnome.org/GNOME/gtk-osx/raw/52898977f165777ad9ef169f7d4818f2d4c9b731/patches/guile-clocktime.patch";
          sha256 = "12wvwdna9j8795x59ldryv9d84c1j3qdk2iskw09306idfsis207";
        })
      ]
      # 3.0+ cross-compilation fix
      ++ lib.optionals (packageAtLeast "3.0") [
        # Fix cross-compilation, can be removed at next release (as well as the autoreconfHook)
        # Include this only conditionally so we don't have to run the autoreconfHook for the native build.
        (lib.optional (!lib.systems.equals stdenv.hostPlatform stdenv.buildPlatform) (fetchpatch {
          url = "https://cgit.git.savannah.gnu.org/cgit/guile.git/patch/?id=c117f8edc471d3362043d88959d73c6a37e7e1e9";
          hash = "sha256-GFwJiwuU8lT1fNueMOcvHh8yvA4HYHcmPml2fY/HSjw=";
        }))
      ];

    # Explicitly link against libgcc_s, to work around the infamous
    # "libgcc_s.so.1 must be installed for pthread_cancel to work".
    LDFLAGS =
      if packageOlder "2.0" then
        null
      else if packageOlder "2.2" then
        # don't have "libgcc_s.so.1" on darwin
        lib.optionalString (!stdenv.hostPlatform.isDarwin && !stdenv.hostPlatform.isMusl) "-lgcc_s"
      else
        # don't have "libgcc_s.so.1" on clang
        lib.optionalString (stdenv.cc.isGNU && !stdenv.hostPlatform.isStatic) "-lgcc_s";

    # Fix build with gcc15 (3.0 only)
    env = lib.optionalAttrs (packageAtLeast "3.0") {
      NIX_CFLAGS_COMPILE = toString [ "-std=gnu17" ];
    };

    # 1.8 specific preBuild
    preBuild = lib.optionalString (packageOlder "2.0") ''
      sed -e '/lt_dlinit/a  lt_dladdsearchdir("'$out/lib'");' -i libguile/dynl.c
    '';

    postInstall = ''
      wrapProgram $out/bin/guile-snarf --prefix PATH : "${gawk}/bin"
    ''
    # XXX: See http://thread.gmane.org/gmane.comp.lib.gnulib.bugs/18903 for
    # why `--with-libunistring-prefix' and similar options coming from
    # `AC_LIB_LINKFLAGS_BODY' don't work on NixOS/x86_64.
    + (
      if packageOlder "2.0" then
        ''
          sed -i "$out/lib/pkgconfig/guile"-*.pc    \
              -e "s|-lltdl|-L${libtool.lib}/lib -lltdl|g"
        ''
      else if packageOlder "3.0" then
        ''
          sed -i "$out/lib/pkgconfig/guile"-*.pc    \
              -e "s|-lunistring|-L${libunistring}/lib -lunistring|g ;
                  s|^Cflags:\(.*\)$|Cflags: -I${libunistring.dev}/include \1|g ;
                  s|-lltdl|-L${libtool.lib}/lib -lltdl|g ;
                  s|includedir=$out|includedir=$dev|g
                  "
        ''
      else
        ''
          sed -i "$out/lib/pkgconfig/guile"-*.pc    \
              -e "s|-lunistring|-L${libunistring}/lib -lunistring|g ;
                  s|-lltdl|-L${libtool.lib}/lib -lltdl|g ;
                  s|-lcrypt|-L${libxcrypt}/lib -lcrypt|g ;
                  s|^Cflags:\(.*\)$|Cflags: -I${libunistring.dev}/include \1|g ;
                  s|includedir=$out|includedir=$dev|g
                  "
        ''
    );

    # make check doesn't work on darwin
    # On Linuxes+Hydra the tests are flaky; feel free to investigate deeper.
    doCheck = false;
    doInstallCheck = false;

    # guile-3 uses ELF files to store bytecode. strip does not
    # always handle them correctly and destroys the image (3.0 only)
    dontStrip = packageAtLeast "3.0";

    inherit setupHook;

    passthru = rec {
      ekapkgs-update.semver-strategy = "patch";
      effectiveVersion = lib.versions.majorMinor version;
      siteCcacheDir =
        if packageOlder "2.0" then "lib/guile/site-ccache" else "lib/guile/${effectiveVersion}/site-ccache";
      siteDir = if packageOlder "2.0" then "share/guile/site" else "share/guile/site/${effectiveVersion}";
    }
    // lib.optionalAttrs (packageAtLeast "3.0") {
      updateScript = writeScript "update-guile-3" ''
        #!/usr/bin/env nix-shell
        #!nix-shell -i bash -p curl pcre common-updater-scripts

        set -eu -o pipefail

        # Expect the text in format of '"https://ftp.gnu.org/gnu/guile/guile-3.0.8.tar.gz"'
        new_version="$(curl -s https://www.gnu.org/software/guile/download/ |
            pcregrep -o1 '"https://ftp.gnu.org/gnu/guile/guile-(3[.0-9]+).tar.gz"')"
        update-source-version guile_3_0 "$new_version"
      '';
    };

    meta = {
      homepage = "https://www.gnu.org/software/guile/";
      description = "Embeddable Scheme implementation";
      longDescription = ''
        GNU Guile is an implementation of the Scheme programming language, with
        support for many SRFIs, packaged for use in a wide variety of
        environments.  In addition to implementing the R5RS Scheme standard and a
        large subset of R6RS, Guile includes a module system, full access to POSIX
        system calls, networking support, multiple threads, dynamic linking, a
        foreign function call interface, and powerful string processing.
      '';
      license = lib.licenses.lgpl3Plus;
      platforms = lib.platforms.all;
      identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "gnu" version;
    };
  }
  // lib.optionalAttrs (packageAtLeast "2.0" && packageOlder "2.2" && !stdenv.hostPlatform.isLinux) {
    # Work around <https://bugs.gnu.org/14201>.
    SHELL = stdenv.shell;
    CONFIG_SHELL = stdenv.shell;
  }
)

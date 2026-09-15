{
  lib,
  bash,
  binutils,
  coreutils,
  gawk,
  libarchive,
  squashfs-tools,
  buildFHSEnv,
  replaceVarsWith,
  runtimeShell,
  runCommand,
}:

rec {
  appimage-exec = replaceVarsWith {
    src = ./appimage-exec.sh;
    isExecutable = true;
    dir = "bin";
    replacements = {
      inherit runtimeShell;
      path = lib.makeBinPath [
        bash
        binutils.unwrapped
        coreutils
        gawk
        libarchive
        squashfs-tools
      ];
    };
  };

  extract =
    args@{
      pname,
      version,
      name ? null,
      postExtract ? "",
      src,
      ...
    }:
    assert
      name == null
      || throw "The `name` argument is deprecated. Use `pname` and `version` instead to construct the name.";
    runCommand "${pname}-${version}-extracted"
      {
        nativeBuildInputs = [ appimage-exec ];
      }
      ''
        appimage-exec.sh -x $out ${src}
        ${postExtract}
      '';

  # for compatibility, deprecated
  extractType1 = lib.warn "'appimageTools.extractType1' is deprecated, use 'appimageTools.extract' instead" extract;
  extractType2 = lib.warn "'appimageTools.extractType2' is deprecated, use 'appimageTools.extract' instead" extract;
  wrapType1 = lib.warn "'appimageTools.wrapType1' is deprecated, use 'appimageTools.wrapType2' instead" wrapType2;

  wrapAppImage = lib.extendMkDerivation {
    constructDrv = buildFHSEnv;
    excludeDrvArgNames = [ "extraPkgs" ];
    extendDrvArgs =
      finalAttrs:
      prev@{
        contents ? prev.src,
        extraPkgs ? pkgs: [ ],
        meta ? { },
        ...
      }:
      defaultFhsEnvArgs
      // {
        targetPkgs = pkgs: [ appimage-exec ] ++ defaultFhsEnvArgs.targetPkgs pkgs ++ extraPkgs pkgs;

        runScript = "appimage-exec.sh -w ${finalAttrs.contents or prev.src} --";

        meta = {
          sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
        }
        // meta;
      };
  };

  wrapType2 = lib.extendMkDerivation {
    constructDrv = wrapAppImage;
    extendDrvArgs = finalAttrs: args: {
      contents = extract (
        lib.filterAttrs (
          key: value:
          builtins.elem key [
            "pname"
            "version"
            "src"
          ]
        ) finalAttrs
      );

      # passthru src to make nix-update work
      # hack to keep the origin position (unsafeGetAttrPos)
      passthru =
        lib.pipe finalAttrs [
          lib.attrNames
          (lib.remove "src")
          (removeAttrs finalAttrs)
        ]
        // args.passthru or { };
    };
  };

  defaultFhsEnvArgs = {
    # Most of the packages were taken from the Steam chroot
    targetPkgs =
      pkgs: with pkgs; [
        bashInteractive
        which
        perl
        iana-etc
        krb5

        # libraries not on the upstream include list, but nevertheless expected
        # by at least one appimage
        libsecret # For bitwarden, appimage is x86_64 only

        # TODO(corepkgs): port gtk3
        # TODO(corepkgs): port zenity
        # TODO(corepkgs): port xrandr
        # TODO(corepkgs): port xdg-user-dirs (flutter desktop apps)
        # TODO(corepkgs): port xdg-utils
        # TODO(corepkgs): port gsettings-desktop-schemas
        # TODO(corepkgs): port hicolor-icon-theme (silences a gtk warning)
      ];

    # list of libraries expected in an appimage environment:
    # https://github.com/AppImage/pkg2appimage/blob/master/excludelist
    multiPkgs =
      pkgs: with pkgs; [
        desktop-file-utils
        libxrandr
        libxext
        libx11
        libxfixes
        libGL

        libdrm
        xkeyboard-config
        libpciaccess

        glib
        bzip2
        zlib
        gdk-pixbuf

        libxrender
        libxxf86vm
        libxi
        libsm
        libice
        freetype
        curl.gnutls
        nspr
        nss
        fontconfig
        cairo
        pango
        expat
        dbus
        cups
        libcap
        libusb1
        udev
        dbus-glib

        libxt
        libxmu
        libxcb
        libGLU
        libuuid
        libogg
        libvorbis
        openssl
        onetbb
        wayland
        libgbm
        libxkbcommon
        vulkan-loader

        libglut
        libjpeg
        libpng12
        libthai
        libtiff
        pixman
        libcaca
        libgcrypt
        libvpx
        libxft
        alsa-lib

        harfbuzz
        e2fsprogs
        libgpg-error
        keyutils.lib
        fribidi
        p11-kit

        gmp

        # libraries not on the upstream include list, but nevertheless expected
        # by at least one appimage
        libtool.lib # for Synfigstudio
        pciutils # for FreeCAD
        brotli # TwitchDropsMiner

        # TODO(corepkgs): port libxcomposite
        # TODO(corepkgs): port libxtst
        # TODO(corepkgs): port gst_all_1 (gstreamer, gst-plugins-base, gst-plugins-ugly)
        # TODO(corepkgs): port libxinerama
        # TODO(corepkgs): port libxdamage
        # TODO(corepkgs): port libxcursor
        # TODO(corepkgs): port libxscrnsaver
        # TODO(corepkgs): port SDL2, SDL2_image, SDL2_ttf, SDL2_mixer
        # TODO(corepkgs): port atk
        # TODO(corepkgs): port at-spi2-atk
        # TODO(corepkgs): port at-spi2-core
        # TODO(corepkgs): port libudev0-shim
        # TODO(corepkgs): port libxcb-util, libxcb-wm, libxcb-image,
        #                 libxcb-keysyms, libxcb-render-util
        # TODO(corepkgs): port glew_1_10
        # TODO(corepkgs): port libidn
        # TODO(corepkgs): port flac
        # TODO(corepkgs): port libpulseaudio
        # TODO(corepkgs): port libsamplerate
        # TODO(corepkgs): port libmikmod
        # TODO(corepkgs): port libtheora
        # TODO(corepkgs): port speex
        # TODO(corepkgs): port libcanberra
        # TODO(corepkgs): port librsvg
        # TODO(corepkgs): port libvdpau
        # TODO(corepkgs): port libjack2
        # TODO(corepkgs): port pipewire (immersed-vr wayland support)
        # TODO(corepkgs): port libmpg123 (Slippi launcher)
      ];
  };
}

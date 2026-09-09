# Compatibility names only; implementations live in pkgs/ and pkgs-many/.
pkgs:
let
  removed = pkgs.lib.mapAttrs (name: reason: throw "darwin.${name} ${reason}") {
    binutilsDualAs = "has been removed from Nixpkgs; use binutils";
    binutilsDualAs-unwrapped = "has been removed from Nixpkgs; use binutils.unwrapped";
    builder = "was renamed to darwin.linux-builder, which requires NixOS modules";
    ditto = "was removed because it was impure and unused";
    insert_dylib = "was renamed to insert-dylib in Nixpkgs";
    ios-deploy = "was moved to the top-level ios-deploy in Nixpkgs";
    libauto = "was removed because it was broken and unmaintained";
    libresolvHeaders = "was removed; use lib.getInclude libresolv";
    libutilHeaders = "was removed; use lib.getInclude libutil";
    openwith = "was removed because it does not work on macOS 26 or newer";
    postLinkSignHook = "was removed because it is obsolete";
    print-reexports = "was removed because it was unused";
    rewrite-tbd = "was removed; use llvm-readtapi";
    stdenvNoCF = "was removed; use stdenv or stdenvNoCC";
    stubs = "was removed because it was unused";
    sudo = "was removed because it was impure and unused";
    swift-corelibs-foundation = "was removed because it was broken and unused";
  };
  legacyStubs =
    pkgs.lib.genAttrs
      [
        "CF"
        "CarbonHeaders"
        "CommonCrypto"
        "CoreSymbolication"
        "IOKit"
        "Libc"
        "Libinfo"
        "Libm"
        "Libnotify"
        "Librpcsvc"
        "Libsystem"
        "LibsystemCross"
        "Security"
        "apple_sdk"
        "apple_sdk_10_12"
        "apple_sdk_11_0"
        "apple_sdk_12_3"
        "architecture"
        "cf-private"
        "configd"
        "configdHeaders"
        "darwin-stubs"
        "dtrace"
        "eap8021x"
        "hfs"
        "hfsHeaders"
        "launchd"
        "libclosure"
        "libdispatch"
        "libmalloc"
        "libobjc"
        "libplatform"
        "libpthread"
        "mDNSResponder"
        "objc4"
        "ppp"
        "xnu"
      ]
      (
        name:
        throw "darwin.${name} was removed from Nixpkgs; use apple-sdk for SDK libraries and frameworks"
      );
  # TODO: These Nixpkgs packages have not been ported to corepkgs.
  unavailable = pkgs.lib.genAttrs [
    "discrete-scroll"
    "iproute2mac"
    "moltenvk"
    "opencflite"
  ] (name: throw "darwin.${name} is available in Nixpkgs but has not been ported to corepkgs");
  # The VM builders depend on NixOS modules, outside the Darwin package port.
  builders = pkgs.lib.genAttrs [
    "linux-builder"
    "linux-builder-x86_64"
    "linux-builder-vz"
  ] (name: throw "darwin.${name} requires NixOS modules that are not available in corepkgs");
in
removed
// legacyStubs
// unavailable
// builders
// {
  inherit (pkgs)
    AvailabilityVersions
    Csu
    DarwinTools
    ICU
    IOKitTools
    PowerManagement
    adv_cmds
    autoSignDarwinBinariesHook
    basic_cmds
    bootstrapStdenv
    bootstrap_cmds
    cctools
    clang-unwrapped
    copyfile
    developer_cmds
    diskdev_cmds
    doc_cmds
    dyld
    file_cmds
    iosSdkPkgs
    libSystem
    libresolv
    libsbuf
    libutil
    lsusb
    mail_cmds
    misc_cmds
    mkAppleDerivation
    network_cmds
    patch_cmds
    remote_cmds
    removefile
    requireXcode
    shell_cmds
    signingUtils
    sigtool
    sourceRelease
    system_cmds
    text_cmds
    top
    trash
    xattr
    xcode
    xcodeProjectCheckHook
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
    xcode_26_0_1
    xcode_26_0_1_Apple_silicon
    xcode_26_1
    xcode_26_1_1
    xcode_26_1_1_Apple_silicon
    xcode_26_1_Apple_silicon
    xcode_26_2
    xcode_26_2_Apple_silicon
    xcode_26_3
    xcode_26_3_Apple_silicon
    xcode_26_4
    xcode_26_4_1
    xcode_26_4_1_Apple_silicon
    xcode_26_4_Apple_silicon
    xcode_26_5
    xcode_26_5_Apple_silicon
    xcode_26_6
    xcode_26_6_Apple_silicon
    xcode_26_Apple_silicon
    xcode_8_1
    xcode_8_2
    xcode_9_1
    xcode_9_2
    xcode_9_3
    xcode_9_4
    xcode_9_4_1
    xnuHeaders
    ;

  bsdmake = pkgs.bmake;
  cctools-apple = pkgs.cctools;
  cctools-llvm = pkgs.cctools;
  cctools-port = pkgs.cctools;
  libtapi = pkgs.libtapi;
  libunwind = pkgs.callPackage ../pkgs/libunwind/darwin.nix { };

  binutils = pkgs.binutils.darwin;
  binutils-unwrapped = pkgs.binutils.unwrapped.darwin;
  binutilsNoLibc = pkgs.binutils.darwin.noLibc;
  libcxx = pkgs.libcxx.apple;
  libffi = pkgs.libffi.darwin;
  libiconv = pkgs.libiconv.darwin;
  libpcap = pkgs.libpcap.apple;
  locale = pkgs.locale.data;
  ps = pkgs.adv_cmds.ps;
}

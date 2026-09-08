{
  version,
  hash,
  apng-patch-hash ? null,
  packageAtLeast,
  packageOlder,
  mkVariantPassthru,
  ...
}@variantArgs:

{
  lib,
  stdenv,
  fetchurl,
  zlib,
  apngSupport ? packageAtLeast "1.6",
  testers,
  runUnitTests,

  # for passthru.tests (1.6 only)
  cairo ? null,
  freetype ? null,
}:

assert zlib != null || (packageOlder "1.6" && stdenv.hostPlatform != stdenv.buildPlatform);

let
  branch = lib.versions.majorMinor version;

  patchVersion = version;
  patch_src = fetchurl {
    url = "mirror://sourceforge/libpng-apng/libpng-${patchVersion}-apng.patch.gz";
    hash = apng-patch-hash;
  };
  whenPatched = lib.optionalString apngSupport;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "libpng" + whenPatched "-apng";
  inherit version;

  src = fetchurl {
    url = "mirror://sourceforge/libpng/libpng-${version}.tar.xz";
    inherit hash;
  };

  postPatch =
    lib.optionalString apngSupport "gunzip < ${patch_src} | patch -Np1"
    + lib.optionalString (packageOlder "1.6" && stdenv.hostPlatform.isDarwin) ''
      substituteInPlace pngconf.h --replace-fail '<fp.h>' '<math.h>'
    ''
    + lib.optionalString (packageAtLeast "1.6" && stdenv.hostPlatform.isFreeBSD) ''

      sed -i 1i'int feenableexcept(int __mask);' contrib/libtests/pngvalid.c
    '';

  outputs = [
    "out"
    "dev"
    "man"
  ];
  outputBin = lib.optionalString (packageAtLeast "1.6") "dev";

  propagatedBuildInputs = [ zlib ];

  configureFlags = lib.optionals (packageOlder "1.6") [ "--enable-static" ];

  postInstall = lib.optionalString (packageOlder "1.6") ''mv "$out/bin" "$dev/bin"'';

  passthru = mkVariantPassthru variantArgs // {
    ekapkgs-update.semver-strategy = "patch";
    inherit zlib;

    tests = {
      pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;
    }
    // lib.optionalAttrs (packageAtLeast "1.6") {
      pkg-config-install = testers.pkg-config.testInstall finalAttrs.finalPackage { };
      unittests = runUnitTests finalAttrs.finalPackage;
      inherit cairo freetype;
    };
  };

  meta = {
    description =
      "Official reference implementation for the PNG file format" + whenPatched " with animation patch";
    homepage = "http://www.libpng.org/pub/png/libpng.html";
    changelog = lib.optionalString (packageAtLeast "1.6") "https://github.com/pnggroup/libpng/blob/v${version}/CHANGES";
    license = if packageAtLeast "1.6" then lib.licenses.libpng2 else lib.licenses.libpng;
    branch = lib.versions.majorMinor version;
    pkgConfigModules = [
      "libpng"
      "libpng${lib.replaceStrings [ "." ] [ "" ] branch}"
    ];
    platforms = if packageAtLeast "1.6" then lib.platforms.all else lib.platforms.unix;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "libpng" finalAttrs.version;
  };
})

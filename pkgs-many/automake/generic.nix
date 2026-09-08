{
  version,
  src-hash,
  packageAtLeast,
  packageOlder,
  ...
}:

{
  lib,
  stdenv,
  fetchurl,
  perl,
  autoconf,
  updateAutotoolsGnuConfigScriptsHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "automake";
  inherit version;

  src = fetchurl {
    url = "mirror://gnu/automake/automake-${version}.tar.xz";
    hash = src-hash;
  };

  nativeBuildInputs = [
    updateAutotoolsGnuConfigScriptsHook
    autoconf
    perl
  ];
  buildInputs = [ autoconf ];

  setupHook = ./setup-hook.sh;

  # Disable indented log output from Make, otherwise "make.test" will
  # fail.
  preCheck = "unset NIX_INDENT_MAKE";
  doCheck = false; # takes _a lot_ of time, fails 3 out of 2698 tests

  doInstallCheck = false; # runs the same thing, fails the same tests

  # Don't fixup '#! /bin/sh' in Libtool, otherwise it will use the
  # 'fixed' path in generated files!
  dontPatchShebangs = true;

  passthru = {
    ekapkgs-update.semver-strategy = "patch";
  };

  meta = {
    branch = lib.versions.majorMinor version;
    homepage = "https://www.gnu.org/software/automake/";
    description = "GNU standard-compliant makefile generator";
    license = lib.licenses.gpl2Plus;
    longDescription = ''
      GNU Automake is a tool for automatically generating
      `Makefile.in` files compliant with the GNU Coding
      Standards.  Automake requires the use of Autoconf.
    '';
    platforms = lib.platforms.all;
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "gnu" version;
  };
})

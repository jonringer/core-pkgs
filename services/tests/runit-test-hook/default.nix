{
  lib,
  stdenv,
  makeSetupHook,
  runit,
  netcat,
  procps,
}:

makeSetupHook {
  name = "runit-test-hook";

  propagatedBuildInputs = [
    runit
    netcat
    procps
  ];

  substitutions = {
    runitPackage = runit;
    netcatPackage = netcat;
    procpsPackage = procps;
  };

  meta = {
    description = "Setup hook for running runit-supervised services during tests";
    platforms = lib.platforms.unix;
  };
} ./runit-test-hook.sh

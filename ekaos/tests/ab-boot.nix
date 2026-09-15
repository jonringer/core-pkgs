# A/B boot test
# Validates boot counting on BLS entries and the bless-boot service.
# A/B semantics come from the existing generation system —
# /run/booted-system is the "A" slot, /run/current-system is the "B".

{ pkgs, ... }:

{
  name = "ab-boot";

  meta.description = "Test A/B boot with boot counting";

  nodes = {
    machine =
      { config, pkgs, ... }:
      {
        boot.kernelPackages = pkgs.linuxPackages;
        boot.loader.systemd-boot.enable = true;

        boot.ab = {
          enable = true;
          bootCountTriesLeft = 3;
          healthCheck = {
            command = "true"; # Always pass in test
            timeout = 30;
          };
        };

        virtualisation.enable = true;
        virtualisation.enableNetwork = true;
      };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # -- Booted and current system should match at boot --
    machine.succeed("test -L /run/booted-system")
    machine.succeed("test -L /run/current-system")
    booted = machine.succeed("readlink /run/booted-system").strip()
    current = machine.succeed("readlink /run/current-system").strip()
    assert booted == current, (
        f"booted ({booted}) != current ({current}) at boot time"
    )
    print(f"System: {booted}")

    # -- Bless-boot service should run and complete --
    machine.succeed("systemctl cat ekaos-bless-boot.service")
    machine.wait_for_unit("ekaos-bless-boot.service")
    print("ekaos-bless-boot.service completed")

    # -- After blessing, no boot counting suffixes should remain --
    entries = machine.succeed("ls /boot/loader/entries/ 2>/dev/null || echo 'none'")
    print(f"Boot entries: {entries}")
    assert "+" not in entries, f"boot counting suffix still present after blessing: {entries}"

    machine.shutdown()
  '';
}

# ekaos test suite

{
  pkgs ? import ../.. { },
}:

{
  # A/B boot partition test
  ab-boot = pkgs.ekaosTest ./ab-boot.nix;

  # Basic boot test
  simple = pkgs.ekaosTest ./simple.nix;

  # Service management test
  service = pkgs.ekaosTest ./service.nix;

  # SQLite service test
  service-sqlite = pkgs.ekaosTest ./service-sqlite.nix;

  # HTTP server service test
  service-http = pkgs.ekaosTest ./service-http.nix;

  # Boot process test
  boot-process = pkgs.ekaosTest ./boot-process.nix;

  # Login functionality test (Phase 1)
  login = pkgs.ekaosTest ./login.nix;

  # Network and SSH test (Phase 2)
  network = pkgs.ekaosTest ./network.nix;

  # Critical MVP packages test (nano, cronie, timesyncd)
  critical-packages = pkgs.ekaosTest ./critical-packages.nix;

  # User services (users.services.*) module tests
  user-services = import ./user-services.nix { inherit pkgs; };

  # Facter hardware auto-detection tests (pure eval, no VM)
  facter = import ./facter.nix { inherit pkgs; };
}

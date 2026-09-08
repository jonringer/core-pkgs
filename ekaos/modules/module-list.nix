# List of base ekaos modules
# These are loaded for every system configuration
[
  # Boot modules
  ./boot/kernel.nix
  ./boot/initrd.nix
  ./boot/stage-2.nix
  ./boot/systemd-boot.nix
  ./boot/modprobe.nix
  ./boot/zfs.nix
  ./boot/grow-partition.nix
  ./boot/swraid.nix
  ./boot/crash-dump.nix
  ./boot/bootspec.nix
  ./boot/containers.nix
  ./boot/kexec.nix
  ./boot/plymouth.nix
  ./boot/binfmt.nix
  ./boot/zswap.nix

  # Hardware
  ./hardware/firmware.nix
  ./hardware/facter
  ./hardware/cpu.nix
  ./hardware/trackpoint.nix
  ./hardware/sensor/iio.nix

  # System modules
  ./system/toplevel.nix
  ./system/package-manifest.nix
  ./system/activation.nix
  ./system/etc.nix
  ./system/logind.nix

  # Tasks
  ./tasks/filesystems.nix
  ./tasks/swap.nix
  ./tasks/timers.nix
  ./tasks/tmpfiles.nix

  # Config modules
  ./config/users-groups.nix
  ./config/locale.nix
  ./config/fonts.nix
  ./config/power.nix
  ./config/kernel-profile.nix
  ./config/xdg/mime.nix
  ./config/xdg/icons.nix
  ./config/xdg/autostart.nix
  ./config/xdg/menus.nix
  ./config/xdg/sounds.nix
  ./config/xdg/portal.nix
  ./config/xdg/terminal-exec.nix
  ./config/shell-environment.nix
  ./config/sysctl.nix
  ./config/nsswitch.nix
  ./config/coredump.nix
  ./config/nix-daemon.nix
  ./config/nixpkgs.nix
  ./config/user-services.nix
  ./config/home.nix
  ./networking.nix
  ./network-interfaces.nix
  ./networking/firewall.nix
  ./networking/nat.nix
  ./networking/nftables.nix
  ./networking/iproute2.nix
  ./networking/dns-zones.nix
  ./networking/port-contracts.nix
  ./networking/wireguard.nix

  # Security modules
  ./security/pam.nix
  ./security/wrappers
  ./security/sudo.nix
  ./security/acme.nix
  ./security/audit.nix
  ./security/hardening.nix

  # Language modules
  ./languages/bun.nix
  ./languages/c.nix
  ./languages/clojure.nix
  ./languages/cplusplus.nix
  ./languages/crystal.nix
  ./languages/cue.nix
  ./languages/deno.nix
  ./languages/dotnet.nix
  ./languages/elixir.nix
  ./languages/erlang.nix
  ./languages/fortran.nix
  ./languages/gawk.nix
  ./languages/gleam.nix
  ./languages/go.nix
  ./languages/guile.nix
  ./languages/hare.nix
  ./languages/haskell.nix
  ./languages/idris.nix
  ./languages/java.nix
  ./languages/javascript.nix
  ./languages/jsonnet.nix
  ./languages/julia.nix
  ./languages/kotlin.nix
  ./languages/lobster.nix
  ./languages/lean.nix
  ./languages/lua.nix
  ./languages/nim.nix
  ./languages/nix.nix
  ./languages/nodejs.nix
  ./languages/ocaml.nix
  ./languages/odin.nix
  ./languages/opentofu.nix
  ./languages/perl.nix
  ./languages/php.nix
  ./languages/pkl.nix
  ./languages/purescript.nix
  ./languages/python.nix
  ./languages/racket.nix
  ./languages/raku.nix
  ./languages/r-lang.nix
  ./languages/ruby.nix
  ./languages/rust.nix
  ./languages/scala.nix
  ./languages/shell.nix
  ./languages/sml.nix
  ./languages/solidity.nix
  ./languages/tcl.nix
  ./languages/terraform.nix
  ./languages/texlive.nix
  ./languages/typst.nix
  ./languages/typescript.nix
  ./languages/unison.nix
  ./languages/vala.nix
  ./languages/vlang.nix
  ./languages/zig.nix

  # Program modules
  ./programs/git.nix

  # Service modules
  ./services/dbus.nix
  ./services/getty.nix
  ./services/crond.nix
  ./services/fstrim.nix
  ./services/resolved.nix
  ./services/timesyncd.nix
  ./services/journald.nix
  ./services/earlyoom.nix
  ./services/stubs.nix
  ./services/queued-build-hook.nix
  ./services/networking/dhcpcd.nix
  ./services/networking/sshd.nix
  ./services/networking/bind.nix
  ./services/networking/unbound.nix
  ./services/networking/networkmanager.nix
  ./services/networking/dnsmasq.nix
  ./services/networking/modemmanager.nix
  ./services/networking/pppd.nix
  ./services/networking/nginx.nix
  ./services/databases/postgresql.nix
  ./services/databases/redis.nix

  ./services/hardware/thermald.nix
  ./services/hardware/fwupd.nix
  ./services/hardware/fprintd.nix
  ./services/hardware/udev.nix

  # Service management
  ./services.nix # Cross-platform service definitions
  # Service manager implementations (opt-in via enable options)
  ./service-managers/systemd.nix
  ./service-managers/runit.nix
  ./service-managers/launchd.nix
  ./service-managers/rcd.nix

  # Monitoring
  ./monitoring/prometheus-scrape.nix
  ./services/monitoring/prometheus.nix

  # Installer
  ./installer/iso-image.nix

  # Miscellaneous
  ./misc/assertions.nix # Assertion checking
  ./misc/defaults.nix # System defaults (including default service manager)

  # Virtualisation
  ./virtualisation/qemu-guest-agent.nix
  ./virtualisation/qemu-vm.nix
  ./virtualisation/podman.nix
  ./virtualisation/docker.nix
  ./virtualisation/libvirtd.nix
  ./virtualisation/containers.nix
]

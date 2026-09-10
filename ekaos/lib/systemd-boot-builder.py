#! @python3@/bin/python3 -B
import argparse
import ctypes
import datetime
import errno
import os
import re
import shutil
import subprocess
import sys
import tempfile
import warnings
import json
from typing import NamedTuple, Any, Sequence
from dataclasses import dataclass
from pathlib import Path

# These values will be replaced with actual values during the package build
EFI_SYS_MOUNT_POINT = Path("@efiSysMountPoint@")
BOOT_MOUNT_POINT = Path("@bootMountPoint@")
LOADER_CONF = EFI_SYS_MOUNT_POINT / "loader/loader.conf"  # Always stored on the ESP
NIXOS_DIR = Path("@nixosDir@".strip("/")) # Path relative to the XBOOTLDR or ESP mount point
TIMEOUT = "@timeout@"
EDITOR = "@editor@" == "1" # noqa: PLR0133
CONSOLE_MODE = "@consoleMode@"
DISTRO_NAME = "@distroName@"
NIX = "@nix@"
SYSTEMD = "@systemd@"
CONFIGURATION_LIMIT = int("@configurationLimit@")
REBOOT_FOR_BITLOCKER = "@rebootForBitlocker@" == "1"  # noqa: PLR0133
CAN_TOUCH_EFI_VARIABLES = "@canTouchEfiVariables@"
GRACEFUL = "@graceful@"
STORE_DIR = "@storeDir@"
EFI_TYPE = json.loads("@efiType@")  # e.g. ["efi"] or ["uki"] or ["efi", "uki"]
AB_ENABLED = "@abEnabled@" == "1"  # noqa: PLR0133
AB_BOOT_COUNT_TRIES = int("@abBootCountTries@") if AB_ENABLED else 0

@dataclass
class BootSpec:
    init: Path
    initrd: Path
    kernel: Path
    kernelParams: list[str]  # noqa: N815
    label: str
    system: str
    toplevel: Path
    specialisations: dict[str, "BootSpec"]
    sortKey: str  # noqa: N815
    devicetree: Path | None = None  # noqa: N815
    initrdSecrets: str | None = None  # noqa: N815
    uki: Path | None = None


libc = ctypes.CDLL("libc.so.6")

FILE = None | int

def run(cmd: Sequence[str | Path], stdout: FILE = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=True, text=True, stdout=stdout)

class SystemIdentifier(NamedTuple):
    profile: str | None
    generation: int
    specialisation: str | None


def copy_if_not_exists(source: Path, dest: Path) -> None:
    if not dest.exists():
        tmpfd, tmppath = tempfile.mkstemp(dir=dest.parent, prefix=dest.name, suffix='.tmp.')
        shutil.copyfile(source, tmppath)
        os.fsync(tmpfd)
        shutil.move(tmppath, dest)


def generation_dir(profile: str | None, generation: int) -> Path:
    if profile:
        return Path(f"/nix/var/nix/profiles/system-profiles/{profile}-{generation}-link")
    else:
        return Path(f"/nix/var/nix/profiles/system-{generation}-link")

def system_dir(profile: str | None, generation: int, specialisation: str | None) -> Path:
    d = generation_dir(profile, generation)
    if specialisation:
        return d / "specialisation" / specialisation
    else:
        return d

BOOT_ENTRY = """title {title}
sort-key {sort_key}
version Generation {generation} {description}
linux {kernel}
initrd {initrd}
options {kernel_params}
"""

def generation_conf_filename(profile: str | None, generation: int, specialisation: str | None) -> str:
    pieces = [
        "nixos",
        profile or None,
        "generation",
        str(generation),
        f"specialisation-{specialisation}" if specialisation else None,
    ]
    return "-".join(p for p in pieces if p) + ".conf"


def write_loader_conf(profile: str | None, generation: int, specialisation: str | None) -> None:
    tmp = LOADER_CONF.with_suffix(".tmp")
    with tmp.open('x') as f:
        f.write(f"timeout {TIMEOUT}\n")
        if "efi" in EFI_TYPE:
            # Use traditional BLS Type #1 entry as default
            f.write("default %s\n" % generation_conf_filename(profile, generation, specialisation))
        elif "uki" in EFI_TYPE:
            # For UKI-only mode, set default by UKI filename (Type #2)
            f.write("default %s\n" % generation_uki_filename(profile, generation, specialisation))
        if not EDITOR:
            f.write("editor 0\n")
        if REBOOT_FOR_BITLOCKER:
            f.write("reboot-for-bitlocker yes\n")
        f.write(f"console-mode {CONSOLE_MODE}\n")
        f.flush()
        os.fsync(f.fileno())
    os.rename(tmp, LOADER_CONF)


def get_bootspec(profile: str | None, generation: int) -> BootSpec:
    system_directory = system_dir(profile, generation, None)
    boot_json_path = (system_directory / "boot.json").resolve()
    if not boot_json_path.is_file():
        print(f"error: boot.json not found at {boot_json_path}", file=sys.stderr)
        sys.exit(1)
    with boot_json_path.open("r") as f:
        try:
            bootspec_json = json.load(f)
        except ValueError as e:
            print(f"error: Malformed Json: {e}, in {boot_json_path}", file=sys.stderr)
            sys.exit(1)
    return bootspec_from_json(bootspec_json)

def bootspec_from_json(bootspec_json: dict[str, Any]) -> BootSpec:
    specialisations = bootspec_json.get('org.nixos.specialisation.v1', {})
    specialisations = {k: bootspec_from_json(v) for k, v in specialisations.items()}
    systemdBootExtension = bootspec_json.get('org.nixos.systemd-boot', {})
    sortKey = systemdBootExtension.get('sortKey', 'nixos')
    devicetree = systemdBootExtension.get('devicetree')
    uki = systemdBootExtension.get('uki')

    if devicetree:
        devicetree = Path(devicetree)
    if uki:
        uki = Path(uki)

    main_json = bootspec_json['org.nixos.bootspec.v1']
    for attr in ("kernel", "initrd", "toplevel"):
        if attr in main_json:
            main_json[attr] = Path(main_json[attr])
    return BootSpec(
        **main_json,
        specialisations=specialisations,
        sortKey=sortKey,
        devicetree=devicetree,
        uki=uki,
    )


def copy_from_file(file: Path, dry_run: bool = False) -> Path:
    """
    Copy a file to the boot filesystem (XBOOTLDR if in use, otherwise ESP), basing the destination filename on the store path that's being copied from. Return the destination path, relative to the boot filesystem mountpoint.
    """
    store_file_path = file.resolve()
    suffix = store_file_path.name
    store_subdir = store_file_path.relative_to(STORE_DIR).parts[0]
    efi_file_path = NIXOS_DIR / (f"{suffix}.efi" if suffix == store_subdir else f"{store_subdir}-{suffix}.efi")
    if not dry_run:
        copy_if_not_exists(store_file_path, BOOT_MOUNT_POINT / efi_file_path)
    return efi_file_path


def write_entry(profile: str | None, generation: int, specialisation: str | None,
                machine_id: str | None, bootspec: BootSpec, current: bool) -> None:
    if specialisation:
        bootspec = bootspec.specialisations[specialisation]
    kernel = copy_from_file(bootspec.kernel)
    initrd = copy_from_file(bootspec.initrd)
    devicetree = copy_from_file(bootspec.devicetree) if bootspec.devicetree is not None else None

    title = "{name}{profile}{specialisation}".format(
        name=DISTRO_NAME,
        profile=" [" + profile + "]" if profile else "",
        specialisation=" (%s)" % specialisation if specialisation else "")

    try:
        if bootspec.initrdSecrets is not None:
            run([bootspec.initrdSecrets, BOOT_MOUNT_POINT / initrd])
    except subprocess.CalledProcessError:
        if current:
            print("failed to create initrd secrets!", file=sys.stderr)
            sys.exit(1)
        else:
            print("warning: failed to create initrd secrets "
                  f'for "{title} - Configuration {generation}", an older generation', file=sys.stderr)
            print("note: this is normal after having removed "
                  "or renamed a file in `boot.initrd.secrets`", file=sys.stderr)
    entry_file = BOOT_MOUNT_POINT / "loader/entries" / generation_conf_filename(profile, generation, specialisation)
    tmp_path = entry_file.with_suffix(".tmp")
    kernel_params = "init=%s " % bootspec.init

    kernel_params = kernel_params + " ".join(bootspec.kernelParams)
    build_time = int(system_dir(profile, generation, specialisation).stat().st_ctime)
    build_date = datetime.datetime.fromtimestamp(build_time).strftime('%F')

    with tmp_path.open("w") as f:
        f.write(BOOT_ENTRY.format(title=title,
                    sort_key=bootspec.sortKey,
                    generation=generation,
                    kernel=f"/{kernel}",
                    initrd=f"/{initrd}",
                    kernel_params=kernel_params,
                    description=f"{bootspec.label}, built on {build_date}"))
        if machine_id is not None:
            f.write("machine-id %s\n" % machine_id)
        if devicetree is not None:
            f.write(f"devicetree /{devicetree}\n")
        f.flush()
        os.fsync(f.fileno())
    tmp_path.rename(entry_file)


def generation_uki_filename(profile: str | None, generation: int, specialisation: str | None) -> str:
    pieces = [
        "ekaos",
        profile or None,
        "generation",
        str(generation),
        f"specialisation-{specialisation}" if specialisation else None,
    ]
    return "-".join(p for p in pieces if p) + ".efi"


def write_uki_entry(profile: str | None, generation: int, specialisation: str | None,
                    bootspec: BootSpec) -> None:
    if specialisation:
        bootspec = bootspec.specialisations[specialisation]
    if bootspec.uki is None:
        print(f"warning: no UKI found for generation {generation}, skipping UKI entry", file=sys.stderr)
        return

    uki_filename = generation_uki_filename(profile, generation, specialisation)
    uki_dest = EFI_SYS_MOUNT_POINT / "EFI/Linux" / uki_filename
    copy_if_not_exists(bootspec.uki, uki_dest)


def get_generations(profile: str | None = None) -> list[SystemIdentifier]:
    gen_list = run(
        [
            f"{NIX}/bin/nix-env",
            "--list-generations",
            "-p",
            "/nix/var/nix/profiles/%s"
            % ("system-profiles/" + profile if profile else "system"),
        ],
        stdout=subprocess.PIPE,
    ).stdout
    gen_lines = gen_list.split("\n")
    gen_lines.pop()

    configurationLimit = CONFIGURATION_LIMIT
    configurations = [
        SystemIdentifier(
            profile=profile,
            generation=int(line.split()[0]),
            specialisation=None
        )
        for line in gen_lines
    ]
    return configurations[-configurationLimit:]


def remove_old_entries(gens: list[SystemIdentifier]) -> None:
    rex_profile = re.compile(r"^nixos-(.*)-generation-.*\.conf$")
    rex_generation = re.compile(r"^nixos.*-generation-([0-9]+)(-specialisation-.*)?\.conf$")
    known_paths = []
    for gen in gens:
        bootspec = get_bootspec(gen.profile, gen.generation)
        known_paths.append(copy_from_file(bootspec.kernel, True).name)
        known_paths.append(copy_from_file(bootspec.initrd, True).name)
        if bootspec.devicetree is not None:
            known_paths.append(copy_from_file(bootspec.devicetree, True).name)

    # Clean up old BLS Type #1 entries
    if "efi" in EFI_TYPE:
        # Match both regular entries and boot-counted entries (+N-M suffix)
        rex_counted = re.compile(r"^(nixos.*-generation-[0-9]+(?:-specialisation-[^+]*)?)\+\d+-\d+\.conf$")
        for path in (BOOT_MOUNT_POINT / "loader/entries").glob("nixos*-generation-[1-9]*", case_sensitive=False):
            # Strip boot counting suffix for generation extraction
            name = path.name
            counted_match = rex_counted.match(name)
            if counted_match:
                name = counted_match.group(1) + ".conf"

            if rex_profile.match(name):
                prof = rex_profile.sub(r"\1", name)
            else:
                prof = None
            try:
                gen_number = int(rex_generation.sub(r"\1", name))
            except ValueError:
                continue
            if (prof, gen_number, None) not in gens:
                path.unlink()
        for path in (BOOT_MOUNT_POINT / NIXOS_DIR).iterdir():
            if path.name not in known_paths and not path.is_dir():
                path.unlink()

    # Clean up old UKI files
    if "uki" in EFI_TYPE:
        uki_dir = EFI_SYS_MOUNT_POINT / "EFI/Linux"
        if uki_dir.is_dir():
            known_uki_names = set()
            for gen in gens:
                known_uki_names.add(generation_uki_filename(gen.profile, gen.generation, None))
                bootspec = get_bootspec(gen.profile, gen.generation)
                for specialisation in bootspec.specialisations.keys():
                    known_uki_names.add(generation_uki_filename(gen.profile, gen.generation, specialisation))
            for path in uki_dir.glob("ekaos-*.efi"):
                if path.name not in known_uki_names:
                    path.unlink()


def cleanup_esp() -> None:
    for path in (EFI_SYS_MOUNT_POINT / "loader/entries").glob("nixos*"):
        path.unlink()
    nixos_dir = EFI_SYS_MOUNT_POINT / NIXOS_DIR
    if nixos_dir.is_dir():
        shutil.rmtree(nixos_dir)


def get_profiles() -> list[str]:
    system_profiles = Path("/nix/var/nix/profiles/system-profiles/")
    if system_profiles.is_dir():
        return [x.name
            for x in system_profiles.iterdir()
            if not x.name.endswith("-link")]
    else:
        return []

def install_bootloader(args: argparse.Namespace) -> None:
    try:
        with open("/etc/machine-id") as machine_file:
            machine_id = machine_file.readlines()[0].strip()
    except IOError as e:
        if e.errno != errno.ENOENT:
            raise
        machine_id = None

    if os.getenv("NIXOS_INSTALL_GRUB") == "1":
        warnings.warn("NIXOS_INSTALL_GRUB env var deprecated, use NIXOS_INSTALL_BOOTLOADER", DeprecationWarning)
        os.environ["NIXOS_INSTALL_BOOTLOADER"] = "1"

    # flags to pass to bootctl install/update
    bootctl_flags = []

    if BOOT_MOUNT_POINT != EFI_SYS_MOUNT_POINT:
        bootctl_flags.append(f"--boot-path={BOOT_MOUNT_POINT}")

    if CAN_TOUCH_EFI_VARIABLES != "1":
        bootctl_flags.append("--no-variables")

    if GRACEFUL == "1":
        bootctl_flags.append("--graceful")

    if os.getenv("NIXOS_INSTALL_BOOTLOADER") == "1":
        # bootctl uses fopen() with modes "wxe" and fails if the file exists.
        LOADER_CONF.unlink(missing_ok=True)

        run(
            [f"{SYSTEMD}/bin/bootctl", f"--esp-path={EFI_SYS_MOUNT_POINT}"]
            + bootctl_flags
            + ["install"]
        )
    else:
        # Update bootloader to latest if needed
        available_out = run(
            [f"{SYSTEMD}/bin/bootctl", "--version"], stdout=subprocess.PIPE
        ).stdout.split()[2]
        installed_out = run(
            [f"{SYSTEMD}/bin/bootctl", f"--esp-path={EFI_SYS_MOUNT_POINT}", "status"],
            stdout=subprocess.PIPE,
        ).stdout

        # See status_binaries() in systemd bootctl.c for code which generates this
        # Matches
        # Available Boot Loaders on ESP:
        #  ESP: /boot (/dev/disk/by-partuuid/9b39b4c4-c48b-4ebf-bfea-a56b2395b7e0)
        # File: └─/EFI/systemd/systemd-bootx64.efi (systemd-boot 255.2)
        # But also:
        # Available Boot Loaders on ESP:
        #  ESP: /boot (/dev/disk/by-partuuid/9b39b4c4-c48b-4ebf-bfea-a56b2395b7e0)
        # File: ├─/EFI/systemd/HashTool.efi
        #       └─/EFI/systemd/systemd-bootx64.efi (systemd-boot 255.2)
        installed_match = re.search(r"^\W+.*/EFI/(?:BOOT|systemd)/.*\.efi \(systemd-boot ([\d.]+[^)]*)\)$",
                      installed_out, re.IGNORECASE | re.MULTILINE)

        available_match = re.search(r"^\((.*)\)$", available_out)

        if installed_match is None:
            raise Exception("Could not find any previously installed systemd-boot. If you are switching to systemd-boot from a different bootloader, you need to run `nixos-rebuild switch --install-bootloader`")

        if available_match is None:
            raise Exception("could not determine systemd-boot version")

        installed_version = installed_match.group(1)
        available_version = available_match.group(1)

        if installed_version < available_version:
            print("updating systemd-boot from %s to %s" % (installed_version, available_version), file=sys.stderr)
            run(
                [f"{SYSTEMD}/bin/bootctl", f"--esp-path={EFI_SYS_MOUNT_POINT}"]
                + bootctl_flags
                + ["update"]
            )

    if "efi" in EFI_TYPE:
        (BOOT_MOUNT_POINT / NIXOS_DIR).mkdir(parents=True, exist_ok=True)
        (BOOT_MOUNT_POINT / "loader/entries").mkdir(parents=True, exist_ok=True)
    if "uki" in EFI_TYPE:
        (EFI_SYS_MOUNT_POINT / "EFI/Linux").mkdir(parents=True, exist_ok=True)

    gens = get_generations()
    for profile in get_profiles():
        gens += get_generations(profile)

    remove_old_entries(gens)

    default_gen = None
    for gen in gens:
        try:
            bootspec = get_bootspec(gen.profile, gen.generation)
            is_default = Path(bootspec.init).parent == Path(args.default_config)

            if "efi" in EFI_TYPE:
                write_entry(*gen, machine_id, bootspec, current=is_default)
                for specialisation in bootspec.specialisations.keys():
                    write_entry(gen.profile, gen.generation, specialisation, machine_id, bootspec, current=is_default)

            if "uki" in EFI_TYPE:
                write_uki_entry(*gen, bootspec)

            if is_default:
                default_gen = gen
                write_loader_conf(*gen)
        except OSError as e:
            # See https://github.com/NixOS/nixpkgs/issues/114552
            if e.errno == errno.EINVAL:
                profile = f"profile '{gen.profile}'" if gen.profile else "default profile"
                print("ignoring {} in the list of boot entries because of the following error:\n{}".format(profile, e), file=sys.stderr)
            else:
                raise e

    # A/B boot counting: rename the default entry to add a boot counting suffix.
    # If the boot fails N times, systemd-boot falls back to the previous entry.
    if AB_ENABLED and default_gen is not None and "efi" in EFI_TYPE:
        conf_name = generation_conf_filename(*default_gen)
        conf_path = BOOT_MOUNT_POINT / "loader/entries" / conf_name
        if conf_path.exists():
            counted_name = conf_name.replace(".conf", f"+{AB_BOOT_COUNT_TRIES}-0.conf")
            counted_path = conf_path.with_name(counted_name)
            conf_path.rename(counted_path)
            print(f"A/B boot counting: {conf_name} -> {counted_name}", file=sys.stderr)

            # Update loader.conf to point to the renamed entry
            LOADER_CONF.unlink(missing_ok=True)
            tmp = LOADER_CONF.with_suffix(".tmp")
            with tmp.open('x') as f:
                f.write(f"timeout {TIMEOUT}\n")
                f.write(f"default {counted_name}\n")
                if not EDITOR:
                    f.write("editor 0\n")
                if REBOOT_FOR_BITLOCKER:
                    f.write("reboot-for-bitlocker yes\n")
                f.write(f"console-mode {CONSOLE_MODE}\n")
                f.flush()
                os.fsync(f.fileno())
            os.rename(tmp, LOADER_CONF)

    if BOOT_MOUNT_POINT != EFI_SYS_MOUNT_POINT:
        # Cleanup any entries in ESP if xbootldrMountPoint is set.
        # If the user later unsets xbootldrMountPoint, entries in XBOOTLDR will not be cleaned up
        # automatically, as we don't have information about the mount point anymore.
        cleanup_esp()


def main() -> None:
    parser = argparse.ArgumentParser(description=f"Update {DISTRO_NAME}-related systemd-boot files")
    parser.add_argument('default_config', metavar='DEFAULT-CONFIG', help=f"The default {DISTRO_NAME} config to boot")
    args = parser.parse_args()

    try:
        install_bootloader(args)
    finally:
        # Since fat32 provides little recovery facilities after a crash,
        # it can leave the system in an unbootable state, when a crash/outage
        # happens shortly after an update. To decrease the likelihood of this
        # event sync the efi filesystem after each update.
        rc = libc.syncfs(os.open(f"{BOOT_MOUNT_POINT}", os.O_RDONLY))
        if rc != 0:
            print(f"could not sync {BOOT_MOUNT_POINT}: {os.strerror(rc)}", file=sys.stderr)

        if BOOT_MOUNT_POINT != EFI_SYS_MOUNT_POINT:
            rc = libc.syncfs(os.open(EFI_SYS_MOUNT_POINT, os.O_RDONLY))
            if rc != 0:
                print(f"could not sync {EFI_SYS_MOUNT_POINT}: {os.strerror(rc)}", file=sys.stderr)


if __name__ == '__main__':
    main()

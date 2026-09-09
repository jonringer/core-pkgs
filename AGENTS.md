# Agent Guide for core-pkgs

This document provides high-level guidelines for AI agents working with the core-pkgs repository. For detailed information on specific topics, see the `.agents/skills/` directory.

**Quick access to detailed guides:**
- [`.agents/skills/cmake/SKILL.md`](.agents/skills/cmake/SKILL.md) - CMake build system
- [`.agents/skills/meson/SKILL.md`](.agents/skills/meson/SKILL.md) - Meson build system
- [`.agents/skills/packaging/SKILL.md`](.agents/skills/packaging/SKILL.md) - Packaging conventions, including dependency management, cross-compilation, and passthru attributes
- [`.agents/skills/validation/SKILL.md`](.agents/skills/validation/SKILL.md) - Validation and testing, including troubleshooting and advanced validation
- [`.agents/skills/porting/SKILL.md`](.agents/skills/porting/SKILL.md) - Porting from nixpkgs, including complete examples and best practices
- [`.agents/skills/mk-many-variants/SKILL.md`](.agents/skills/mk-many-variants/SKILL.md) - Multi-version packages in pkgs-many
- [`docs/common-issues/`](docs/common-issues/README.md) - Fixing build failures after version updates

## Package Organization

Packages in `pkgs/` and `pkgs-many/` are automatically added to the `pkgs.*` package scope based on their directory name.

### `pkgs/` Directory

Individual packages are placed in `pkgs/<package-name>/default.nix`. The package is automatically available as `pkgs.<package-name>` without requiring an explicit entry in `top-level.nix`.

**Example:**
```
pkgs/
  libxslt/
    default.nix
    77-Use-a-dedicated-node-type-to-maintain-the-list-of-cached-rv-ts.patch
```

This package is automatically available as `pkgs.libxslt`.

**When to add an explicit entry in `top-level.nix`:**
- Only add an explicit entry if the **inputs deviate** from the inputs declared in the nix expression
- Or if you need to override default arguments
- Or if you need to provide additional configuration

**Example of explicit entry (when needed):**
```nix
# In top-level.nix
libxslt = callPackage ./pkgs/libxslt {
  # Override default inputs
  pythonSupport = false;
  cryptoSupport = true;
};
```

### Alternative Implementations

Keep alternative implementations in the same package directory, using multiple
files: `default.nix` is a short selector, `generic.nix` contains the usual implementation,
and `darwin.nix` contains Apple's implementation. Keep selection and implementation
attributes inside the package folder, without entries in `top-level.nix`. Use
ordinary `if` expressions and `callPackage`, forwarding explicit overrides.
Keep implementation-specific patches and support files in a matching subdirectory.
Avoid separate `apple-<package>` entries for an existing package family.

Expose an explicit attribute such as `libpcap.apple` when callers need to choose
an implementation themselves. Preserve `.override` and `.overrideAttrs` on each
implementation. For `pkgs-many/` families, keep the existing variant structure
and dispatch to separate implementation files from `generic.nix`. Use short
variant names such as `real`, `darwin`, and `v3_3`; do not repeat the package name
in package-local aliases.

### `pkgs-many/` Directory

Packages that produce multiple variants should use the `mkManyVariants` paradigm and be placed in `pkgs-many/`.

**Example structure:**
```
# Uses mkManyVariants to create python39, python310, python311, etc.
pkgs-many/python/default.nix
```

The variants are automatically available in the package scope (e.g., `pkgs.python39`, `pkgs.python310`).

## Commit Message Conventions

- **New packages:** `<pkg>: init at <version>` (e.g., `libavif: init at 1.4.2`)
- **Version updates:** `<pkg>: <old version> -> <new version>` (e.g., `libxpm: 3.5.18 -> 3.5.19`)
- **ekaos modules:** `ekaos/<module>: init | <succinct message>` (e.g., `ekaos/nginx: init`, `ekaos/networking: add firewall options`)
- **Do not** add AI attribution (e.g., `Co-Authored-By`) to commit messages

## Packaging Conventions

### Meta Attributes

**Never set `meta.maintainers` or `meta.teams`:**

This repo is curated as a set, so packages carry neither. Neither is a recognised
`meta` key, so setting one fails `check-meta`; simply omit them.

```nix
meta = {
  description = "Example package";
  license = lib.licenses.mit;
  platforms = lib.platforms.linux;
};
```

**Detailed guide:** See [`.agents/skills/packaging/SKILL.md`](.agents/skills/packaging/SKILL.md) for complete meta attribute documentation.

### Testing

- `doCheck = false;` is the default - don't set it explicitly
- Prefer `passthru.tests` for unit tests
- Only enable `doCheck = true;` for critical packages

**Detailed guide:** See [`.agents/skills/packaging/SKILL.md`](.agents/skills/packaging/SKILL.md#testing) for testing patterns.

### Build Systems

**CMake packages:**

Include `cmake.configurePhaseHook` in nativeBuildInputs.

**Detailed guide:** See [`.agents/skills/cmake/SKILL.md`](.agents/skills/cmake/SKILL.md) for complete CMake documentation.

**Meson packages:**

Include `meson.configurePhaseHook` and `ninja` in nativeBuildInputs. `mesonBuildType` defaults
to `release`; set it only when a package requires a different build type.

**Detailed guide:** See [`.agents/skills/meson/SKILL.md`](.agents/skills/meson/SKILL.md) for complete Meson documentation.

## Checking if Dependencies Exist

Before porting a package, verify that all required dependencies are available in core-pkgs.

**Use `nix-instantiate` to check if a dependency exists:**

```bash
nix-instantiate -A <dependency-name>
```

If the dependency exists, you'll see the derivation path. If it doesn't exist, you'll get an error.

**Example - checking multiple dependencies:**
```bash
for dep in acl lzo cmocka libuuid util-linux zlib zstd; do
  echo -n "$dep: "
  nix-instantiate -A $dep >/dev/null 2>&1 && echo "✓ available" || echo "✗ missing"
done
```

**Important:** Do NOT search `top-level.nix` with grep to check for dependencies. Packages in `pkgs/` and `pkgs-many/` are automatically registered and may not appear in `top-level.nix`. Always use `nix-instantiate` to verify availability.

## Validation

All added or edited package attributes **must** pass three steps:

1. **Evaluate** — `nix-instantiate -A <package-name>` verifies the Nix expression evaluates correctly. For non-derivation attrs use `nix-instantiate --eval -A <attr>`.
2. **Build** — `nix-build -A <package-name>` verifies the package builds successfully.
3. **Format** — `nix fmt <path-to-file>` ensures code follows formatting standards.

Before submitting changes, also confirm:

- [ ] All dependencies verified with `nix-instantiate -A <dep>`
- [ ] Package in correct directory (`pkgs/` or `pkgs-many/`)
- [ ] No `meta.maintainers` or `meta.teams`
- [ ] TODO comments added for missing dependencies

**Detailed guide:** See [`.agents/skills/validation/SKILL.md`](.agents/skills/validation/SKILL.md) for complete validation procedures, troubleshooting, advanced validation techniques, and the [full checklist](.agents/skills/validation/SKILL.md#validation-checklist).

## Porting from nixpkgs

When porting a package from nixpkgs:

1. **Check dependencies first** - see [Checking if Dependencies Exist](#checking-if-dependencies-exist)
2. **Copy the package files** to the appropriate directory (`pkgs/` or `pkgs-many/`)
3. **Strip nixpkgs-only fields** - `meta.maintainers`, `meta.teams`, and update scripts (e.g., `updateScript = gnome.updateScript { ... }`)
4. **Add TODO comments** for missing dependencies
5. **Validate** and **format** the files - see [Validation](#validation)

**Detailed guide:** See [`.agents/skills/porting/SKILL.md`](.agents/skills/porting/SKILL.md) for complete porting workflow, examples, and troubleshooting.

## Fixing Build Failures After Version Updates

See [`docs/common-issues/`](docs/common-issues/README.md) for detailed guides on fixing build failures. The most frequent patterns:

- **Obsolete patches** — Remove `fetchpatch`/`fetchurl` entries that are already applied upstream. Also clean up unused imports. See [obsolete-patches.md](docs/common-issues/obsolete-patches.md).
- **Python build system changes** — Upstream switches from `setuptools` to `hatchling`, pins incompatible tool versions, or adds unavailable dependencies. See [python-packages.md](docs/common-issues/python-packages.md).
- **Compiler `-Werror` failures** — Suppress specific warnings with `env.NIX_CFLAGS_COMPILE`. See [compiler-errors.md](docs/common-issues/compiler-errors.md).
- **CMake install paths** — Major version bumps may need explicit `-DCMAKE_INSTALL_INCLUDEDIR`/`-DCMAKE_INSTALL_LIBDIR` flags. See [cmake-packages.md](docs/common-issues/cmake-packages.md).
- **Rust/Go hash mismatches** — Update `cargoHash`/`vendorHash`, or patch `go.mod` version pins. See [rust-packages.md](docs/common-issues/rust-packages.md).
- **Transitive dependency failures** — "Build failed due to failed dependency" means a *different* package is broken. Fix that one first. See [dependency-failures.md](docs/common-issues/dependency-failures.md).
- **mkManyVariants packages** — Version and hash live in `variants.nix`, not `default.nix`.

## ekaos Reusable Modules

ekaos provides **reusable service modules** using a cross-platform service interface that works across systemd, launchd, runit, and BSD rc.d.

**Quick reference:** See `services/AGENTS.md` for service definition syntax and conventions.

**Key points:**
- Service modules in `ekaos/modules/services/` define options at `services.*`
- Services are automatically translated to systemd units
- Same interface works across multiple platforms and contexts
- Full documentation in `services/README.md`

**Example service module structure:**
```nix
services.myservice = {
  enable = true;
  command = "${pkgs.myapp}/bin/myapp";
  args = [ "--port" "8080" ];
  restartPolicy = "always";

  systemd = {
    wantedBy = [ "multi-user.target" ];
  };
};
```

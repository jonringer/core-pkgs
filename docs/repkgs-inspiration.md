# Feasibility Analysis: Integrating repkgs Concepts into core-pkgs

[repkgs](https://github.com/Mic92/repkgs) is Mic92's ground-up reimagining of Nix-based packaging.
It introduces six architectural innovations worth evaluating for adoption:

1. Single LLVM toolchain
2. Cross-compilation as the default code path
3. Relocatable outputs
4. Nushell-based builders
5. Content-addressed compilation cache (jig/jigd)
6. Dynamic derivations for lock file processing

This document evaluates the feasibility of adopting each concept into core-pkgs.

## At a Glance

| Priority | Feature | Value | Cost | Verdict |
|----------|---------|-------|------|---------|
| 1 | Compilation Cache | High (dev velocity) | Low (additive) | **Strong yes** |
| 2 | Dynamic Derivations | Very high (eliminates vendor hashes) | Medium-High (experimental Nix) | **Yes, high leverage** |
| 3 | Single LLVM Toolchain | High (architecture) | High (incremental) | **Yes, incrementally** |
| 4 | Relocatable Outputs | Medium (deployment) | Medium (opt-in) | **Yes, as opt-in** |
| 5 | Cross-Compilation | Medium (simplicity) | Very high (rewrite) | **Partial only** |
| 6 | Nushell Builders | Medium (DX) | Extreme (rewrite) | **No** |

### Feature Independence

```
Compilation Cache   ─── fully independent, adopt now
Dynamic Derivations ─── requires jig (from Cache) or standalone worker-protocol client
LLVM Toolchain      ─── independent; enables Cross-Compilation and Relocatable Outputs
Relocatable Outputs ─── independent; benefits from LLVM Toolchain
Cross-Compilation   ─── benefits from LLVM Toolchain; high coupling to existing architecture
Nushell Builders    ─── independent but impractical for an existing codebase
```

---

## Feature 1: Single LLVM Toolchain

### What repkgs does

Unified Clang/LLVM + lld for all platforms (x86_64, aarch64, riscv64, loongarch64,
powerpc64le, mingw-w64). Two-stage bootstrap: musl-based stage0 produces a minimal
toolchain, stage1 cross-compiles platform-specific glibc/musl variants. No per-platform
compiler wrappers — a single driver selects the target via flags.

### Where core-pkgs stands

- GCC-based on Linux, Clang on Darwin
- `pkgsLLVM` variant in `stdenv/variants.nix` (`useLLVM = true; linker = "lld"`)
- cc-wrapper already handles both GCC and Clang
- LLVM 18–22 packaged in `pkgs-many/llvm/`

### Assessment

| Dimension | Rating |
|-----------|--------|
| Technical feasibility | Yes, with caveats |
| Migration path | Incremental via `pkgsLLVM` |
| Impact scope | Bootstrap chain rewrite + ~60 packages with compiler-specific code |
| Compatibility risk | High — GCC extensions, Fortran (gfortran), kernel builds |
| Effort | XL full switch; M to make `pkgsLLVM` robust |

### Hard blockers

- **Fortran.** gfortran is the only mature option; LLVM's flang is not ready for all
  use cases (openblas, fftw quad-precision, lapack-reference, R).
- **Linux kernel and bootloaders** strongly prefer or require GCC.
- **Bootstrap chain.** The 7-stage GCC bootstrap in `stdenv/linux/default.nix` would
  need a full rewrite for an LLVM-based chain.

### Recommended partial adoption

Make `pkgsLLVM` first-class with CI coverage. Fix packages that fail under Clang/LLD
one by one. Eventually swap the default, keeping GCC available as `gccStdenv`.
This captures ~80% of the value (unified toolchain, simpler cross-compilation,
faster builds) without a big-bang migration.

**Key files:** `stdenv/linux/default.nix`, `build-support/cc-wrapper/default.nix`,
`stdenv/variants.nix`

---

## Feature 2: Cross-Compilation as Default

### What repkgs does

No native/cross distinction — every build is a cross build. Two dependency categories
only: `buildDependencies` (tools for the build machine) and `dependencies` (target
libraries). Replaces the 6-way platform matrix
(`pkgsBuildBuild`/`pkgsBuildHost`/`pkgsBuildTarget`/`pkgsHostHost`/`pkgsHostTarget`/`pkgsTargetTarget`).

### Where core-pkgs stands

- Full 3-stage cross-compilation with `buildPackages`/`hostPackages`/`targetPackages`
- Splicing system in `stdenv/splice.nix`
- `strictDeps = true` by default (the most impactful step, already done)

### Assessment

| Dimension | Rating |
|-----------|--------|
| Technical feasibility | Partially |
| Migration path | Cannot be adopted incrementally in pure form |
| Impact scope | Splice system, every package scope, all ~800 packages |
| Compatibility risk | Very high — splicing is deeply embedded |
| Effort | XL for full adoption; S for improving cross CI |

### Hard blockers

- **Splicing is woven into `callPackage`**, `makeScopeWithSplicing`, and every
  language-specific package scope. Removing it touches everything.
- **The 6-way matrix serves a real purpose** for compiler toolchains where the
  build/host/target distinction genuinely matters.
- **Full rewrite would break every package scope.**

### Recommended partial adoption

Keep the existing splice system. Improve cross-compilation CI coverage. Fix packages
that fail when cross-compiled. `strictDeps = true` already captures the main
conceptual benefit (clean build-time vs run-time dependency separation).

**Key files:** `stdenv/splice.nix`, `stdenv/stage.nix`, `stdenv/cross/default.nix`

---

## Feature 3: Relocatable Outputs

### What repkgs does

All binaries use `$ORIGIN`-relative RPATHs instead of absolute `/nix/store/` paths.
A `launch` wrapper handles scripts. A `dlaudit` LD_AUDIT module validates
relocatability at build time. Outputs can be copied to any filesystem location and
still work.

### Where core-pkgs stands

- Absolute `/nix/store/` RPATHs; auto-patchelf sets absolute paths
- Already has related infrastructure: glibc `ldcache.patch` adds
  `_dl_find_ekaos_cache` with PT_NOTE-based library resolution, and
  `generate-ld-cache.sh` writes these notes via patchelf
- This proves comfort with ELF post-processing pipelines

### Assessment

| Dimension | Rating |
|-----------|--------|
| Technical feasibility | Yes |
| Migration path | Incremental, opt-in per package |
| Impact scope | cc-wrapper RPATH generation, auto-patchelf, fixup phase |
| Compatibility risk | Medium — multi-output packages are the hard case |
| Effort | L for opt-in; XL for default |

### Hard challenge: multiple outputs

A binary in `$out/bin/` linking a library in `$lib/lib/` cannot use simple
`$ORIGIN/../lib` because they are in different store paths. Solutions exist
(symlink forests, deep relative paths like `$ORIGIN/../../../<hash>/lib`) but
add complexity.

### Recommended partial adoption

Add an opt-in `relocatable = true` flag to `mkDerivation` that:

1. Switches cc-wrapper RPATH injection to `$ORIGIN`-relative
2. Modifies auto-patchelf to rewrite absolute paths to relative
3. Adds a validation step that copies the output and verifies it still works

This builds naturally on the existing ld-cache infrastructure and does not
disrupt non-relocatable packages.

**Key files:** `build-support/cc-wrapper/cc-wrapper.sh`,
`build-support/setup-hooks/auto-patchelf.sh`,
`pkgs/auto-patchelf/source/auto-patchelf.py`,
`stdenv/generic/setup.sh` (fixup phase)

---

## Feature 4: Nushell Builders

### What repkgs does

Nushell modules replace bash entirely. Build systems live in `.nu` files. A single
`nu` interpreter runs per build, with phases as function calls. Structured data,
`par-each` parallelism, and proper error handling via `x` prefix.

### Where core-pkgs stands

- 1829-line `setup.sh` defining all phases
- 48 setup hooks (~2375 lines of bash)
- Every package's inline hooks are bash
- `__structuredAttrs = true` by default already provides JSON-based attribute passing

### Assessment

| Dimension | Rating |
|-----------|--------|
| Technical feasibility | Yes, in isolation |
| Migration path | Big-bang rewrite required |
| Impact scope | Every file in the repository |
| Compatibility risk | Extreme |
| Effort | XL+ (multi-year) |

### Why not

This is the most disruptive possible change:

- Rewriting `setup.sh` (1829 lines) and all 48 setup hooks
- Translating every inline bash snippet in 800+ packages
- Adding `nu` to the bootstrap closure
- Training contributors on Nushell
- Maintaining a bash compatibility layer during transition (which negates the benefits)

core-pkgs already gets the main "structured data" benefit from `__structuredAttrs = true`.
The remaining benefits (better error handling, parallelism) do not justify a complete
rewrite of a working system.

**Verdict: Not recommended.** repkgs was built from scratch for Nushell. Migrating an
existing codebase is strictly harder, and the cost-benefit ratio is unfavorable.

---

## Feature 5: Compilation Cache (jig/jigd)

### What repkgs does

jig (compiler wrapper) + jigd (daemon) provide content-addressed object file caching.
The wrapper hashes source + flags + includes and checks the cache before running
the compiler. The daemon manages storage and build parallelism. The cache socket is
mapped into the Nix sandbox via `--sandbox-paths`, so it does not affect derivation
hashes — it is a pure performance optimization. ~90% cache hit rate in typical
development.

### Where core-pkgs stands

- No integrated compilation cache
- Relies on Nix's derivation-level binary substitution
- cc-wrapper has `isCcache` support but no active integration

### Assessment

| Dimension | Rating |
|-----------|--------|
| Technical feasibility | Yes |
| Migration path | Fully incremental, purely additive |
| Impact scope | Zero changes to existing packages |
| Compatibility risk | None |
| Effort | M |

### Implementation

1. Package `jig` and `jigd` in `pkgs/`
2. Create a build wrapper that detects the jigd socket and passes `--sandbox-paths`
3. Document deployment (jigd systemd service, `nix.conf` extra-sandbox-paths)
4. Optionally add a `stdenv/adapters.nix` entry for `useCacheStdenv`

If jigd is not running, builds proceed normally — zero impact. When running,
rebuilds after recipe changes go from minutes to seconds for C/C++/Rust/Go packages.

### Alternative consideration

ccache/sccache are mature alternatives. jig's key advantage is content-addressing
independent of derivation hash — ccache with `CCACHE_BASEDIR` approaches this but
is not identical. Whether to adopt jig specifically versus ccache/sccache is a
practical choice; the concept is valuable regardless of implementation.

**Key files:** No existing files change. New: `pkgs/jig/default.nix`,
`pkgs/jigd/default.nix`, wrapper script.

---

## Feature 6: Dynamic Derivations for Lock File Processing

### What repkgs does

Uses Nix's experimental `ca-derivations` + `dynamic-derivations` features to
eliminate vendor hashes entirely. The mechanism has three parts:

1. **Producer derivation** (content-addressed): runs a script that reads the lock
   file from the already-fetched source, extracts each dependency's hash from
   the lock file itself, and creates `builtin:fetchurl` derivations via the Nix
   worker protocol (through `jig nix-store add-drv`). Covers Cargo.lock,
   package-lock.json, pnpm-lock.yaml, yarn.lock, bun.lock, Gemfile.lock,
   mix.lock, rebar.lock, and uv.lock.

2. **Collector derivation** (content-addressed): assembles the fetched
   dependencies into a vendor directory layout.

3. **System library discovery**: producers match locked dependency names
   against a lookup table (e.g., `openssl-sys` crate maps to the repkgs
   `openssl` package) to automatically pull in system libraries without the
   package recipe listing them.

At eval time, the package only sees `builtins.outputOf producer.outPath "out"` —
a placeholder string. Lock files are never parsed at eval time and no hashes
appear in Nix code. Version bumps require updating only the source version and
hash; the lock file's own checksums are authoritative.

### Where core-pkgs stands

- **Fixed-Output Derivations (FODs) with manual hash management** for all vendor
  dependencies: `cargoHash`, `vendorHash`, `npmDepsHash` must be updated manually
  on every version bump
- `__contentAddressed` is supported in `make-derivation.nix` and can be toggled
  via `config.contentAddressedByDefault`
- No `builtins.outputOf` usage anywhere
- IFD is actively avoided
- The "fake hash → real hash" workflow is documented in
  `docs/common-issues/rust-packages.md`

### Assessment

| Dimension | Rating |
|-----------|--------|
| Technical feasibility | Yes, but requires experimental Nix features |
| Migration path | Incremental per-ecosystem (Rust first, then Go, Node, etc.) |
| Impact scope | `build-support/rust/`, `build-support/go/`, fetcher packages |
| Compatibility risk | Medium — requires Nix daemon with `ca-derivations` + `dynamic-derivations` |
| Effort | L–XL |

### Hard blockers

- **Experimental Nix features required.** `ca-derivations` and
  `dynamic-derivations` must be enabled in `nix.conf`. These are still marked
  experimental. The Nix daemon and all build machines must opt in.

- **jig dependency.** Producer derivations communicate with the Nix daemon via
  `jig nix-store`, repkgs' custom worker protocol client. Either jig must be
  adopted (coupling to Feature 5) or an equivalent tool must be written.

- **`builtins.outputOf` semantics.** Returns a placeholder string at eval time
  that only resolves after the producer builds. Some Nix tooling
  (nix-instantiate, nix eval, nix flake show) may not handle placeholders
  gracefully.

- **Binary cache compatibility.** CA derivations produce content-addressed output
  paths. Binary caches must support CA outputs — supported but not universal.

### What core-pkgs gains

- **Eliminates vendor hash maintenance.** No more `cargoHash`, `vendorHash`,
  `npmDepsHash` fields. Version bumps require only updating the source hash.

- **Eliminates the "fake hash → real hash" workflow.** The entire pattern of
  "set hash to empty, build fails, copy real hash" disappears.

- **Faster evaluation.** Lock files are not parsed at eval time.

- **Automatic system library discovery.** Producers can discover which system
  libraries are needed from lock files, reducing manual dependency listing.

### Recommended adoption path

1. **Enable `ca-derivations` experimentally** in `nix.conf` on CI and developer
   machines. Low-risk — CA derivations are opt-in per derivation.

2. **Port jig's `nix-store` subcommand** or write a minimal standalone
   worker-protocol client.

3. **Implement for Rust first.** Replace `fetchCargoVendor`/`importCargoLock`
   with a dynamic derivation producer. Rust is the most painful ecosystem
   currently (every version bump requires `cargoHash` updates).

4. **Extend to Go, Node, Python.** Each ecosystem gets its own producer.

5. **Enable `dynamic-derivations`.** Gate behind a config flag initially.

### Alternative: partial value without dynamic derivations

Use IFD (import-from-derivation) to read lock files at eval time and generate
per-dependency FODs automatically. This avoids experimental features but adds
eval-time builds. core-pkgs currently avoids IFD, but it is a known pattern.

**Key files:** `build-support/rust/fetch-cargo-vendor.nix`,
`build-support/rust/import-cargo-lock.nix`,
`build-support/rust/build-rust-package/default.nix`,
`build-support/go/module.nix`, `pkgs/fetchNpmDeps/default.nix`,
`stdenv/generic/make-derivation.nix` (CA support)

---

## Recommended Path Forward

```
Now         ─── Package jig/jigd for compilation caching (Feature 5)
Near-term   ─── Pursue dynamic derivations (Feature 6) — highest value-to-effort ratio
Medium-term ─── Make Clang/LLD the default via pkgsLLVM (Feature 1)
Opportunistic── Add opt-in $ORIGIN-relative RPATHs (Feature 3)
```

repkgs was designed as a clean-room reimplementation where every feature assumes
the others exist. core-pkgs is an evolved codebase with deep architectural
commitments. The features that work as additive layers — compilation caching,
dynamic derivations, opt-in relocatability — are highly feasible. The features
that require replacing foundational infrastructure — Nushell builders,
cross-compilation model — are not practical without effectively rewriting
core-pkgs from scratch.

Dynamic derivations deserve special attention: they solve the single most tedious
maintenance task in Nix packaging (vendor hash updates on every version bump).
The main barrier is requiring experimental Nix features, which is a
deployment/policy decision rather than an engineering one.

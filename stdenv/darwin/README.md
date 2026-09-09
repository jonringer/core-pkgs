# Darwin support in corepkgs

Ported from `/home/qweered/Projects/nixpkgs` at
`04d294a46080bab12cb340e8a1d7f8283768b91b`.
The upstream bootstrap currently supports **aarch64-darwin**. It has no Intel
Darwin bootstrap files.

| Upstream attribute | corepkgs attribute |
| --- | --- |
| `darwin.binutils` | `binutils` |
| `darwin.binutils-unwrapped` | `binutils.unwrapped` |
| `darwin.binutilsNoLibc` | `binutils.noLibc` |
| `darwin.libffi` | `libffi` |
| `darwin.libpcap` | `libpcap.apple` |
| `darwin.locale` (locale data) | `locale.data` |

Nixpkgs compatibility names are provided by `stdenv/aliases.nix`, including
`libffiReal`, `libiconvReal`, and the former flat binutils names. The `darwin`
namespace is a compatibility view defined in `stdenv/darwin-aliases.nix`; its
packages point to the implementations above. Set `config.allowAliases = false`
to disable these names. Removed releases such as `libffi_3_3` still throw, as do
legacy SDK stubs and unported packages in the compatibility namespace.

`libffi.real` selects upstream and `libffi.darwin` selects Apple’s implementation. Use `libiconv.real` for upstream libiconv.
`locale` remains the platform-selected command from `unixtools`, with data
available as `locale.data`. Platform selection lives in a short `default.nix` within each family,
with separate implementation files (`generic.nix` and `darwin.nix`). SDKs remain
available as `apple-sdk`, `apple-sdk_14`, `apple-sdk_15`, and `apple-sdk_26`.
The SDK's bootstrap override disables propagation while building its own inputs.
Binutils implementations and wrappers share `pkgs-many/binutils/`. Darwin targets use
`darwin.nix`; GNU binutils remains available as `binutils.unwrapped.real`.
`binutils.unwrapped-all-targets` selects the raw GNU build with all targets.
Versions are defined in `variants.nix`, and `wrappers.nix` defines the normal
and `noLibc` wrappers.
`mkAppleDerivation` resolves source-release Meson templates in these flat package
directories and adds corepkgs' explicit Meson configure hook.

The original bootstrap stage assertions and final allowed/disallowed requisites
checks are retained. `freshBootstrapTools` selects the Darwin tools on Darwin;
its `test-pkgs` rebuilds stdenv using `config.replaceBootstrapFiles`.

The evaluation checks cover the imported packages, the bootstrap generator and
self-test, a stdenv using freshly generated bootstrap files, compiler identity,
SDK overrides, and the LLVM variant/override interface. They do not execute
Darwin binaries or establish that the complete native bootstrap builds.

Build `stdenv` and `freshBootstrapTools.test` on an `aarch64-darwin` builder for
native validation. `nom-build-jon` is the package build entrypoint in this
workspace, but its current remote store is Linux-only. Linux-to-Darwin cross
builds are also excluded by the upstream `cctools` platform metadata. The
portable helpers `sigtool`, `pbzx`, and `dumpnar` can be built on Linux.

Xcode retains upstream's `requireFile` behavior; the SDK/bootstrap does not
require the proprietary Xcode download. The upstream NixOS VM builder wrappers
are outside the stdenv/package port and require NixOS modules absent here.

# Darwin stdenv design goals

There are two more goals worth calling out explicitly:

1. The standard environment should build successfully with sandboxing enabled on Darwin. It is
   fine if a package requires a `sandboxProfile` to build, but it should not be necessary to
   disable the sandbox to build the stdenv successfully; and
2. The output should depend weakly on the bootstrap tools. Historically, Darwin required updating
   the bootstrap tools prior to updating the version of LLVM used in the standard environment.
   By not depending on a specific version, the LLVM used on Darwin can be updated simply by
   bumping the definition of llvmPackages in `top-level.nix`.

# Updating the stdenv

There are effectively two steps when updating the standard environment:

1. Update the definition of llvmPackages in `top-level.nix` for Darwin to match the value of
   llvmPackages.latest in `top-level.nix`. Timing-wise, this is done currently using the spring
   release of LLVM and once `llvmPackages.latest` has been updated to match. If the LLVM project
   has announced a release schedule of patch updates, wait until those are in Nixpkgs. Otherwise,
   the LLVM updates will have to go through staging instead of being merged into master; and
2. Fix the resulting breakage. Most things break due to additional warnings being turned into
   errors or additional strictness applied by LLVM. Fixes may come in the form of disabling those
   new warnings or by fixing the actual source (e.g., with a patch or update upstream). If the
   fix is trivial (e.g., adding a missing int to an implicit declaration), it is better to fix
   the problem instead of silencing the warning.

# shellcheck shell=bash
#
# wrapDriverProgram / autoWrapDriverPrograms
#
# Wraps a nix-built executable so that it can use host-provided
# hardware-acceleration libraries on non-NixOS systems while still
# using nix-built libraries everywhere else.
#
# Usage:
#   wrapDriverProgram /full/path/to/program          # wrap a single binary
#   autoWrapDriverPrograms                            # wrap all dynamic-ELF
#                                                     # files in $prefix/bin
#
# Substitutions provided by makeSetupHook (see default.nix):
#   @cc@                  - C compiler
#   @wrapperSource@       - path to wrapper.c
#   @wdpConfigHeader@     - path to generated wdp-config.h.in template
#   @nixGlibc@            - nix glibc lib output (provides libc.so.6)
#   @nixLibStdCxx@        - nix libstdc++ lib output (or empty)
#   @configHash@          - stable hash bound to libraries.nix + paths
#

set -o pipefail

# Use the host stdenv's isELF if available; otherwise define our own.
if ! declare -F isELF >/dev/null 2>&1; then
    isELF() {
        local fn="$1"
        local fd magic
        exec {fd}< "$fn" || return 1
        LANG=C read -r -n 4 -u "$fd" magic
        exec {fd}<&-
        [ "$magic" = $'\177ELF' ]
    }
fi

# Returns 0 if file is a dynamically-linked ELF executable (ET_EXEC or ET_DYN
# with PT_INTERP). Used to skip ELF .so files and static binaries.
_wdpIsDynamicExecutable() {
    local fn="$1"
    [ -f "$fn" ] || return 1
    [ -x "$fn" ] || return 1
    isELF "$fn" || return 1
    # Check for PT_INTERP: read the program header table looking for type 3.
    # Easier: rely on `file`-style heuristic via readelf if present, else
    # fall back to a `head`-of-binary scan for "/ld-".
    if command -v readelf >/dev/null 2>&1; then
        readelf -l "$fn" 2>/dev/null | grep -q "INTERP" || return 1
        return 0
    fi
    # Best-effort fallback: dynamic linker path is in the first 4 KiB of any
    # PIE/ET_DYN executable.
    LANG=C grep -aql "/ld-" "$fn" 2>/dev/null
}

# wrapDriverProgram <program-path>
#   Replace <program-path> with a compiled C launcher that prepares the
#   environment and exec's the original (renamed to .<name>-driver-wrapped).
wrapDriverProgram() {
    local prog="$1"
    if [ -z "$prog" ]; then
        echo "wrapDriverProgram: missing program path" >&2
        return 1
    fi
    if [ ! -f "$prog" ]; then
        echo "wrapDriverProgram: not a file: $prog" >&2
        return 1
    fi
    if ! _wdpIsDynamicExecutable "$prog"; then
        echo "wrapDriverProgram: not a dynamic ELF executable, skipping: $prog" >&2
        return 0
    fi

    local dir base hidden
    dir="$(dirname "$prog")"
    base="$(basename "$prog")"

    # Idempotency: if there's already a wrapped sibling, skip.
    hidden="$dir/.$base-driver-wrapped"
    if [ -e "$hidden" ]; then
        echo "wrapDriverProgram: already wrapped: $prog" >&2
        return 0
    fi

    # Move original aside.
    mv "$prog" "$hidden"

    # Build per-binary config header.
    local tmpdir
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' RETURN

    cp "@wdpConfigHeader@" "$tmpdir/wdp-config.h.in"

    # Substitute REAL_PROGRAM, NIX_LIBC, NIX_LIBSTDCXX, NIX_LD_LINUX, CONFIG_HASH.
    # Other arrays are baked into wdp-config.h.in already (generated at build time).
    local real_program nix_libc nix_libstdcxx nix_ld_linux
    real_program="$hidden"
    nix_libc="@nixGlibc@/lib/libc.so.6"
    nix_libstdcxx="@nixLibStdCxx@"
    if [ -n "$nix_libstdcxx" ] && [ -e "$nix_libstdcxx/lib/libstdc++.so.6" ]; then
        nix_libstdcxx="$nix_libstdcxx/lib/libstdc++.so.6"
    else
        nix_libstdcxx=""
    fi
    nix_ld_linux="@nixGlibc@/lib/ld-linux-x86-64.so.2"
    if [ ! -e "$nix_ld_linux" ]; then
        nix_ld_linux="@nixGlibc@/lib/ld-linux.so.2"
    fi

    # Use sed to replace the @TOKEN@ placeholders in the header template.
    sed \
        -e "s|@WDP_REAL_PROGRAM@|$real_program|g" \
        -e "s|@WDP_NIX_LIBC@|$nix_libc|g" \
        -e "s|@WDP_NIX_LIBSTDCXX@|$nix_libstdcxx|g" \
        -e "s|@WDP_NIX_LD_LINUX@|$nix_ld_linux|g" \
        -e "s|@WDP_CONFIG_HASH@|@configHash@|g" \
        "$tmpdir/wdp-config.h.in" > "$tmpdir/wdp-config.h"

    # Compile the wrapper.
    @cc@ \
        -Wall -Wextra -Wno-unused-parameter -Wno-unused-result \
        -Os -std=c11 \
        -I"$tmpdir" \
        -o "$prog" \
        "@wrapperSource@"

    chmod +x "$prog"

    # Sanity: refuse to leave a half-broken wrapper if compile failed.
    if [ ! -x "$prog" ]; then
        mv "$hidden" "$prog"
        echo "wrapDriverProgram: failed to compile wrapper for $prog; reverted" >&2
        return 1
    fi

    echo "wrapDriverProgram: wrapped $prog (original at $hidden)" >&2
}

# autoWrapDriverPrograms
#   Iterate ${!outputBin}/bin and wrap every dynamic-ELF executable that isn't
#   already wrapped or a symlink. Respects multiple outputs.
autoWrapDriverPrograms() {
    # Support multiple outputs: use outputBin if set, otherwise fall back to out
    local targetOut="${outputBin:-out}"
    local bindir="${!targetOut}/bin"

    if [ ! -d "$bindir" ]; then
        return 0
    fi

    local f
    for f in "$bindir"/*; do
        [ -e "$f" ] || continue
        # Skip symlinks (they'll resolve to a wrapped target on use).
        [ -L "$f" ] && continue
        # Skip already-hidden originals.
        case "$(basename "$f")" in
            .*-driver-wrapped) continue ;;
        esac
        _wdpIsDynamicExecutable "$f" || continue
        wrapDriverProgram "$f"
    done
}

# Register autoWrapDriverPrograms into postFixup if the consuming derivation
# wants automatic behaviour. This only fires when this hook is in
# nativeBuildInputs *and* the derivation set wdpAutoWrap=1 (default 1 unless
# explicitly disabled).
_wdpRegisterAutoWrap() {
    if [ "${wdpAutoWrap:-1}" != "1" ]; then return 0; fi
    postFixupHooks+=(autoWrapDriverPrograms)
}

_wdpRegisterAutoWrap

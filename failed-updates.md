# Failed `--all-variants` Updates

Results from running `ekapkgs-update update --file default.nix --all-variants <pkg>` on every `pkgs-many/` package. Run date: 2026-09-07.

## Failure Categories

### 1. Unsupported URL Schemes (`Could not parse upstream source from URL`)

The tool only supports GitHub, GitLab, SourceHut, and PyPI as upstream sources. Packages fetching from other hosts are not discoverable.

| Package | URL Pattern | Upstream Host |
|---------|-------------|---------------|
| autoconf | `mirror://gnu/autoconf/...` | GNU FTP mirrors |
| automake | `mirror://gnu/automake/...` | GNU FTP mirrors |
| boost | `mirror://sourceforge/boost/...` | SourceForge |
| cmake | `https://cmake.org/files/...` | cmake.org |
| curl | (empty — uses `builtins.fetchurl`) | curl.se |
| db | `https://download.oracle.com/...` | Oracle |
| docbook-xml-dtd | (no `src.url`) | DocBook project |
| flex | `mirror://github/westes/flex/...` | GitHub (via mirror:// scheme) |
| fuse | `mirror://github/libfuse/libfuse/...` | GitHub (via mirror:// scheme) |
| gmp | `mirror://gnu/gmp/...` | GNU FTP mirrors |
| guile | `mirror://gnu/guile/...` | GNU FTP mirrors |
| libiconv | `mirror://gnu/libiconv/...` | GNU FTP mirrors |
| libmicrohttpd | `mirror://gnu/libmicrohttpd/...` | GNU FTP mirrors |
| libpng | `mirror://sourceforge/libpng/...` | SourceForge |
| libtool | `mirror://gnu/libtool/...` | GNU FTP mirrors |
| lua | `https://www.lua.org/ftp/...` | lua.org |
| nasm | `https://www.nasm.us/pub/nasm/...` | nasm.us |
| ncurses | `mirror://gnu/ncurses/...` | GNU FTP mirrors |
| openssl | `https://www.openssl.org/source/...` | openssl.org |
| perl | `mirror://cpan/src/5.0/...` | CPAN |
| r-lang | `https://cran.r-project.org/src/base/...` | CRAN |
| tcl | `mirror://sourceforge/tcl/...` | SourceForge |
| texinfo | `mirror://gnu/texinfo/...` | GNU FTP mirrors |
| tk | `mirror://sourceforge/tcl/...` | SourceForge |
| wayland | `https://gitlab.freedesktop.org/.../archive/...` | freedesktop GitLab (unsupported instance) |

**Enhancement opportunity:** Add support for:
- `mirror://gnu/` — Map to GNU FTP release listing or Savannah API
- `mirror://sourceforge/` — Map to SourceForge release API
- `mirror://github/` — These are actually GitHub URLs; strip the `mirror://` prefix and parse as GitHub
- Custom domain fetchers — Allow `passthru.ekapkgs-update.releases-url` to point at an Atom/JSON feed
- freedesktop.org GitLab — Add as a supported GitLab instance

### 2. Calendar Versioning Mismatch (`No compatible releases found ... with strategy minor`)

Packages using date-based versions (YYYYMMDD) where the `minor` strategy filters by the numeric "major" component, which is the full date — so no release matches.

| Package | Version Example | Issue |
|---------|----------------|-------|
| abseil-cpp | `20250814.2` | Variant `v20250814` infers `minor` strategy, filters for prefix `20250814` — only patch releases `20250814.x` match, not newer dates |

**Enhancement opportunity:** Detect calendar versioning patterns (8-digit numbers) and use a date-range filter instead of semver prefix matching. Or allow `passthru.ekapkgs-update.version-type = "calver"` to opt into date-aware filtering.

### 3. Non-Standard Version Formats (`No compatible releases found`)

Packages with version strings that don't parse as semver, causing the strategy filter to reject all releases.

| Package | Version | Issue |
|---------|---------|-------|
| clojure | `1.12.6.1673` | 4-component version; `minor` filters for `1.12.x` but releases use `1.12.6.NNNN` format |
| crystal | `1.20.3`, `1.21.0` | Already at latest patch within each series — not a real failure |
| bun | `1.3.14`, `1.4.2` | Already at latest patch within each series — not a real failure |

**Enhancement opportunity:** For 4-component versions like clojure, treat the 3rd component as part of the minor series (i.e., `1.12.6.x` for variant `v1_12`).

### 4. Non-GitHub/GitLab Git Forges

| Package | URL Pattern | Forge |
|---------|-------------|-------|
| wayland | `https://gitlab.freedesktop.org/...` | freedesktop GitLab |
| wlroots | `https://gitlab.freedesktop.org/...` | freedesktop GitLab |

**Enhancement opportunity:** The GitLab client should support custom instances via domain matching, not just `gitlab.com`.

### 5. Packages With No src.url (Function-Based Fetchers)

| Package | Issue |
|---------|-------|
| gcc-releases | Uses `fetchurl` with computed URL, `src.url` evaluates to null |
| ghc | Binary distribution, complex multi-source setup |
| java | Uses `fetchurl` with computed URL per JDK vendor |
| linux | Uses `fetchurl` with computed URL from kernel.org |
| nix | Modular build system, components have separate sources |
| rust | Binary bootstrap + source build, multi-stage |

**Enhancement opportunity:** Support `passthru.ekapkgs-update.github-repo = "owner/repo"` to specify the upstream source explicitly when it can't be auto-detected from `src.url`.

### 6. Packages Where --all-variants Worked

| Package | Outcome |
|---------|---------|
| abseil-cpp | 11 new variants added (v20220623 through v20260817), all built |
| protobuf | 3 existing variants updated, 3 new variants added (v34, v35, v36) |
| bun | No new variants (already at latest in each series) |
| deno | No changes needed |

## Summary

| Category | Count | Fix Complexity |
|----------|-------|----------------|
| Unsupported URL scheme | ~25 | Medium — add GNU/SF/custom host support |
| Calendar versioning | 1 | Medium — detect calver, adjust filtering |
| Non-standard versions | 1-2 | Low — handle 4-component versions |
| Non-GitHub GitLab | 2 | Low — support custom GitLab instances |
| No src.url | ~6 | Low — add explicit repo passthru attr |
| Already up-to-date | ~5 | N/A — not real failures |
| **Successful** | **2** | **Working as designed** |

## Recommendations (Priority Order)

1. **Support `mirror://github/`** — Trivial win; these are GitHub URLs with a prefix. Strip prefix and parse normally.
2. **Support custom GitLab instances** — freedesktop.org GitLab covers wayland + wlroots.
3. **Add `passthru.ekapkgs-update.github-repo`** — Explicit upstream source for packages with non-parseable URLs.
4. **Support GNU mirror releases** — `mirror://gnu/<pkg>/` maps to `https://ftp.gnu.org/gnu/<pkg>/` which has directory listings.
5. **Calendar versioning detection** — Detect 8-digit YYYYMMDD versions and adjust strategy.

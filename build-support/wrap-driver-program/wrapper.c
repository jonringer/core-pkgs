/*
 * wrap-driver-program: runtime launcher for nix-built executables that need
 * host-provided hardware-acceleration libraries.
 *
 * On startup, this wrapper:
 *   1. If running on NixOS (/run/opengl-driver/lib exists), prepends that to
 *      LD_LIBRARY_PATH and execs the wrapped program directly.
 *   2. Otherwise, builds (and caches) a per-user "driver shim" directory
 *      under $XDG_CACHE_HOME/nix-driver-wrap/<config-hash>/ containing
 *      symlinks to host driver libraries discovered via /etc/ld.so.cache.
 *   3. Inspects host vs. nix glibc/libstdc++ versions (by reading
 *      .gnu.version_d ELF sections) and decides whether to exec the program
 *      via the host ld.so loader (when host glibc has newer GLIBC_x.y
 *      version definitions than the nix one the program is linked against).
 *   4. Sets driver-related env vars (VK_DRIVER_FILES, __EGL_VENDOR_LIBRARY_FILENAMES,
 *      OCL_ICD_VENDORS, LIBGL_DRIVERS_PATH, LIBVA_DRIVERS_PATH, VDPAU_DRIVER_PATH,
 *      LD_LIBRARY_PATH) and execs the real program.
 *
 * Compile-time substitutions (via -D defines) are expected:
 *   WDP_REAL_PROGRAM       absolute path to wrapped program
 *   WDP_NIX_LIBC           absolute path to the nix libc.so.6 used by the program
 *   WDP_NIX_LIBSTDCXX      absolute path to nix libstdc++.so.6 (or empty)
 *   WDP_NIX_LD_LINUX       absolute path to nix ld-linux loader (informational)
 *   WDP_CONFIG_HASH        short stable hash identifying the wrap config
 *   WDP_LIBRARIES_C        comma-separated C-string list of {name, is_glob}
 *   WDP_CONFIGS_C          comma-separated C-string list of config dirs
 *   WDP_DRIVER_PATHS_C     comma-separated C-string list of driver-path candidates
 *
 * For simplicity, the substituted lists are not provided as #defines but as
 * separate generated arrays via include of "wdp-config.h", which the build
 * step generates next to this file before compilation.
 *
 * SPDX-License-Identifier: MIT
 */

#define _GNU_SOURCE
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <fnmatch.h>
#include <inttypes.h>
#include <libgen.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <elf.h>

#include "wdp-config.h"
/*
 * wdp-config.h provides the following symbols (generated at build time):
 *
 *   static const char *const WDP_REAL_PROGRAM;
 *   static const char *const WDP_NIX_LIBC;
 *   static const char *const WDP_NIX_LIBSTDCXX;     // may be ""
 *   static const char *const WDP_NIX_LD_LINUX;
 *   static const char *const WDP_CONFIG_HASH;
 *
 *   struct wdp_lib { const char *name; int is_glob; };
 *   static const struct wdp_lib WDP_LIBRARIES[];
 *   static const size_t WDP_LIBRARIES_N;
 *
 *   struct wdp_cfg {
 *     const char *const *source_dirs; size_t source_dirs_n;
 *     const char *pattern;
 *     const char *cache_subdir;
 *     const char *const *env_vars; size_t env_vars_n;
 *     int mode_dir;   // 0 = files, 1 = dir
 *   };
 *   static const struct wdp_cfg WDP_CONFIGS[];
 *   static const size_t WDP_CONFIGS_N;
 *
 *   struct wdp_drvpath {
 *     const char *const *candidates; size_t candidates_n;
 *     const char *env_var;
 *   };
 *   static const struct wdp_drvpath WDP_DRIVER_PATHS[];
 *   static const size_t WDP_DRIVER_PATHS_N;
 */

/* ------------------------------------------------------------------------- */
/* Logging / diagnostics                                                     */
/* ------------------------------------------------------------------------- */

static int wdp_debug = 0;

static void wdp_log(const char *fmt, ...) {
    if (!wdp_debug) return;
    va_list ap;
    va_start(ap, fmt);
    fputs("[wrap-driver] ", stderr);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
}

static void wdp_warn(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fputs("[wrap-driver:warn] ", stderr);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
}

/* ------------------------------------------------------------------------- */
/* Small dynamic string                                                      */
/* ------------------------------------------------------------------------- */

typedef struct {
    char *data;
    size_t len;
    size_t cap;
} dstr;

static void dstr_init(dstr *s) { s->data = NULL; s->len = 0; s->cap = 0; }

static void dstr_reserve(dstr *s, size_t need) {
    if (s->cap >= need + 1) return;
    size_t cap = s->cap ? s->cap : 64;
    while (cap < need + 1) cap *= 2;
    char *p = realloc(s->data, cap);
    if (!p) { perror("realloc"); abort(); }
    s->data = p;
    s->cap = cap;
}

static void dstr_append(dstr *s, const char *src, size_t n) {
    dstr_reserve(s, s->len + n);
    memcpy(s->data + s->len, src, n);
    s->len += n;
    s->data[s->len] = '\0';
}

static void dstr_appendc(dstr *s, char c) { dstr_append(s, &c, 1); }
static void dstr_appendz(dstr *s, const char *src) { dstr_append(s, src, strlen(src)); }

static void dstr_appendf(dstr *s, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    va_list ap2;
    va_copy(ap2, ap);
    int needed = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    if (needed < 0) { va_end(ap2); return; }
    dstr_reserve(s, s->len + (size_t)needed);
    vsnprintf(s->data + s->len, (size_t)needed + 1, fmt, ap2);
    s->len += (size_t)needed;
    va_end(ap2);
}

static void dstr_free(dstr *s) { free(s->data); dstr_init(s); }

/* ------------------------------------------------------------------------- */
/* mkdir -p                                                                  */
/* ------------------------------------------------------------------------- */

static int mkdir_p(const char *path, mode_t mode) {
    char tmp[PATH_MAX];
    size_t len = strlen(path);
    if (len == 0 || len >= sizeof(tmp)) { errno = EINVAL; return -1; }
    memcpy(tmp, path, len + 1);
    for (size_t i = 1; i < len; i++) {
        if (tmp[i] == '/') {
            tmp[i] = '\0';
            if (mkdir(tmp, mode) < 0 && errno != EEXIST) return -1;
            tmp[i] = '/';
        }
    }
    if (mkdir(tmp, mode) < 0 && errno != EEXIST) return -1;
    return 0;
}

static int rmtree(const char *path) {
    /* Remove a directory tree. Best-effort: ignores ENOENT. */
    DIR *d = opendir(path);
    if (!d) return errno == ENOENT ? 0 : -1;
    struct dirent *de;
    int rc = 0;
    while ((de = readdir(d))) {
        if (!strcmp(de->d_name, ".") || !strcmp(de->d_name, "..")) continue;
        char child[PATH_MAX];
        snprintf(child, sizeof(child), "%s/%s", path, de->d_name);
        struct stat st;
        if (lstat(child, &st) < 0) { rc = -1; continue; }
        if (S_ISDIR(st.st_mode)) {
            if (rmtree(child) < 0) rc = -1;
        } else {
            if (unlink(child) < 0) rc = -1;
        }
    }
    closedir(d);
    if (rmdir(path) < 0 && errno != ENOENT) rc = -1;
    return rc;
}

/* ------------------------------------------------------------------------- */
/* /etc/ld.so.cache parser                                                   */
/* ------------------------------------------------------------------------- */
/*
 * The format we parse is the "new" libc6 ld.so.cache format used since
 * glibc 2.2:
 *   - magic "ld.so-1.7.0\0" (12 bytes) for the legacy header (skipped)
 *   - then "glibc-ld.so.cache1.1" magic for the new format header
 *
 * On modern systems the file starts with the legacy header (for backward
 * compat) followed by alignment and then the new header. Some distros
 * (e.g. recent Arch) only contain the new header.
 *
 * We do not need to be perfect: we only need to map SONAME -> realpath.
 * Where parsing fails, we fall back to scanning a small set of FHS dirs.
 */

#define CACHEMAGIC      "ld.so-1.7.0"
#define CACHEMAGIC_NEW  "glibc-ld.so.cache"
#define CACHE_VERSION   "1.1"
#define CACHEMAGIC_VERSION_NEW CACHEMAGIC_NEW CACHE_VERSION

struct file_entry_new {
    int32_t flags;
    uint32_t key;
    uint32_t value;
    uint32_t osversion;
    uint64_t hwcap;
};

struct cache_file_new {
    char magic[sizeof(CACHEMAGIC_NEW) - 1];
    char version[sizeof(CACHE_VERSION) - 1];
    uint32_t nlibs;
    uint32_t len_strings;
    uint8_t flags;
    uint8_t padding_unsed[3];
    uint32_t extension_offset;
    uint32_t unused[3];
    /* struct file_entry_new libs[nlibs] */
};

struct file_entry_legacy {
    int32_t flags;
    uint32_t key;
    uint32_t value;
};

struct cache_file_legacy {
    char magic[sizeof(CACHEMAGIC) - 1];
    uint32_t nlibs;
    /* struct file_entry_legacy libs[nlibs] */
};

typedef struct {
    void *map;
    size_t size;
    /* Pointer into mmap'd region for the new-format header (or NULL). */
    const struct cache_file_new *cf_new;
    /* Pointer to the start of the "string table" used by `key`/`value`
     * offsets. For pure new-format caches this is the start of the new
     * header; for combined caches it is also offset from the new header. */
    const char *strtab;
} ldcache_t;

static int ldcache_open(ldcache_t *c, const char *path) {
    c->map = MAP_FAILED;
    c->size = 0;
    c->cf_new = NULL;
    c->strtab = NULL;

    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    struct stat st;
    if (fstat(fd, &st) < 0) { close(fd); return -1; }
    void *m = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (m == MAP_FAILED) return -1;
    c->map = m;
    c->size = (size_t)st.st_size;

    const char *p = (const char *)m;
    size_t off = 0;

    /* Detect legacy header and skip past it. */
    if (c->size >= sizeof(struct cache_file_legacy)
        && memcmp(p, CACHEMAGIC, sizeof(CACHEMAGIC) - 1) == 0) {
        const struct cache_file_legacy *cfl = (const void *)p;
        off = sizeof(struct cache_file_legacy)
            + (size_t)cfl->nlibs * sizeof(struct file_entry_legacy);
        /* New header is aligned to alignof(struct cache_file_new). 8 is enough. */
        off = (off + 7) & ~(size_t)7;
    }

    if (c->size < off + sizeof(struct cache_file_new)) goto fail;

    if (memcmp(p + off, CACHEMAGIC_NEW, sizeof(CACHEMAGIC_NEW) - 1) != 0) {
        /* Some glibc/distros write only the new format. Try at offset 0. */
        if (off != 0
            && memcmp(p, CACHEMAGIC_NEW, sizeof(CACHEMAGIC_NEW) - 1) == 0) {
            off = 0;
        } else {
            goto fail;
        }
    }

    c->cf_new = (const struct cache_file_new *)(p + off);
    c->strtab = (const char *)c->cf_new;
    /* Sanity: nlibs must fit into the file. */
    size_t entries_size = (size_t)c->cf_new->nlibs * sizeof(struct file_entry_new);
    if (off + sizeof(struct cache_file_new) + entries_size > c->size) goto fail;
    return 0;

fail:
    munmap(m, c->size);
    c->map = MAP_FAILED;
    c->size = 0;
    return -1;
}

static void ldcache_close(ldcache_t *c) {
    if (c->map != MAP_FAILED) munmap(c->map, c->size);
    c->map = MAP_FAILED;
    c->size = 0;
    c->cf_new = NULL;
    c->strtab = NULL;
}

/* Look up an exact SONAME. Returns a pointer to the path inside the cache's
 * strtab on success, NULL otherwise. The returned pointer is valid until
 * ldcache_close. */
static const char *ldcache_lookup(const ldcache_t *c, const char *soname) {
    if (!c->cf_new) return NULL;
    const struct file_entry_new *libs =
        (const struct file_entry_new *)((const char *)c->cf_new
                                        + sizeof(struct cache_file_new));
    uint32_t n = c->cf_new->nlibs;
    /* We pick the first matching ELF64-x86_64 entry; on multilib systems
     * there may be 32-bit duplicates. */
    for (uint32_t i = 0; i < n; i++) {
        const char *key = c->strtab + libs[i].key;
        if (strcmp(key, soname) == 0) {
            /* Best-effort architecture filter via flags bits 8-15. */
            int32_t flags = libs[i].flags;
            int type = flags & 0xff;
            (void)type;
            /* Accept first match for now; ldconfig orders by hwcap so first
             * is usually best. */
            return c->strtab + libs[i].value;
        }
    }
    return NULL;
}

/* Iterate over all entries calling cb(soname, path) for each. */
typedef int (*ldcache_iter_cb)(const char *soname, const char *path, void *user);
static void ldcache_iter(const ldcache_t *c, ldcache_iter_cb cb, void *user) {
    if (!c->cf_new) return;
    const struct file_entry_new *libs =
        (const struct file_entry_new *)((const char *)c->cf_new
                                        + sizeof(struct cache_file_new));
    uint32_t n = c->cf_new->nlibs;
    for (uint32_t i = 0; i < n; i++) {
        const char *key = c->strtab + libs[i].key;
        const char *value = c->strtab + libs[i].value;
        if (cb(key, value, user) != 0) return;
    }
}

/* ------------------------------------------------------------------------- */
/* FHS fallback resolution                                                   */
/* ------------------------------------------------------------------------- */

static const char *const FHS_LIB_DIRS[] = {
    "/usr/lib/x86_64-linux-gnu",
    "/usr/lib64",
    "/usr/lib",
    "/lib/x86_64-linux-gnu",
    "/lib64",
    "/lib",
    "/usr/local/lib/x86_64-linux-gnu",
    "/usr/local/lib64",
    "/usr/local/lib",
    NULL,
};

static int file_exists(const char *p) {
    struct stat st;
    return stat(p, &st) == 0 && !S_ISDIR(st.st_mode);
}

static int dir_exists(const char *p) {
    struct stat st;
    return stat(p, &st) == 0 && S_ISDIR(st.st_mode);
}

static char *fhs_lookup_exact(const char *soname) {
    for (size_t i = 0; FHS_LIB_DIRS[i]; i++) {
        char buf[PATH_MAX];
        snprintf(buf, sizeof(buf), "%s/%s", FHS_LIB_DIRS[i], soname);
        if (file_exists(buf)) return strdup(buf);
    }
    return NULL;
}

/* For glob patterns: enumerate FHS dirs and match. Returns a malloc'd
 * NULL-terminated array of malloc'd absolute paths. */
static char **fhs_lookup_glob(const char *pattern, size_t *out_n) {
    char **paths = NULL;
    size_t n = 0, cap = 0;
    for (size_t i = 0; FHS_LIB_DIRS[i]; i++) {
        DIR *d = opendir(FHS_LIB_DIRS[i]);
        if (!d) continue;
        struct dirent *de;
        while ((de = readdir(d))) {
            if (de->d_name[0] == '.') continue;
            if (fnmatch(pattern, de->d_name, 0) != 0) continue;
            char buf[PATH_MAX];
            snprintf(buf, sizeof(buf), "%s/%s", FHS_LIB_DIRS[i], de->d_name);
            if (!file_exists(buf)) continue;
            if (n + 1 >= cap) {
                cap = cap ? cap * 2 : 8;
                paths = realloc(paths, cap * sizeof(*paths));
                if (!paths) { perror("realloc"); abort(); }
            }
            paths[n++] = strdup(buf);
        }
        closedir(d);
    }
    if (paths) paths[n] = NULL;
    *out_n = n;
    return paths;
}

/* ------------------------------------------------------------------------- */
/* ELF parser: extract maximum GLIBC_x.y or GLIBCXX_x.y version definition   */
/* ------------------------------------------------------------------------- */
/*
 * Strategy: open the ELF, find SHT_GNU_verdef (".gnu.version_d") and its
 * linked .dynstr, walk the verdef chain, parse strings of the form
 * "PREFIX_<num>(.<num>)*" and remember the lexicographically maximum version
 * tuple. Returns 0 if no matching version was found.
 *
 * Encoded as a packed uint64: (major << 32) | (minor << 16) | patch.
 */

typedef struct {
    uint32_t major, minor, patch;
} version_t;

static int parse_version_with_prefix(const char *s, const char *prefix, version_t *out) {
    size_t plen = strlen(prefix);
    if (strncmp(s, prefix, plen) != 0) return 0;
    s += plen;
    if (*s == '_') s++;
    else return 0;
    char *end;
    unsigned long maj = strtoul(s, &end, 10);
    if (end == s) return 0;
    out->major = (uint32_t)maj;
    out->minor = 0;
    out->patch = 0;
    if (*end == '.') {
        s = end + 1;
        unsigned long min_ = strtoul(s, &end, 10);
        if (end == s) return 1;
        out->minor = (uint32_t)min_;
        if (*end == '.') {
            s = end + 1;
            unsigned long pat = strtoul(s, &end, 10);
            if (end == s) return 1;
            out->patch = (uint32_t)pat;
        }
    }
    return 1;
}

static int version_cmp(const version_t *a, const version_t *b) {
    if (a->major != b->major) return a->major < b->major ? -1 : 1;
    if (a->minor != b->minor) return a->minor < b->minor ? -1 : 1;
    if (a->patch != b->patch) return a->patch < b->patch ? -1 : 1;
    return 0;
}

static int elf_max_versym(const char *path, const char *prefix, version_t *out) {
    out->major = out->minor = out->patch = 0;
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    struct stat st;
    if (fstat(fd, &st) < 0) { close(fd); return -1; }
    void *m = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (m == MAP_FAILED) return -1;

    int rc = -1;
    const unsigned char *e_ident = (const unsigned char *)m;
    if (st.st_size < (off_t)EI_NIDENT) goto out;
    if (e_ident[EI_MAG0] != ELFMAG0 || e_ident[EI_MAG1] != ELFMAG1
        || e_ident[EI_MAG2] != ELFMAG2 || e_ident[EI_MAG3] != ELFMAG3) goto out;

    if (e_ident[EI_CLASS] == ELFCLASS64) {
        const Elf64_Ehdr *eh = (const Elf64_Ehdr *)m;
        if (eh->e_shoff == 0 || eh->e_shentsize < sizeof(Elf64_Shdr)) goto out;
        const Elf64_Shdr *shdrs = (const Elf64_Shdr *)((const char *)m + eh->e_shoff);
        const Elf64_Shdr *verdef = NULL;
        for (uint16_t i = 0; i < eh->e_shnum; i++) {
            if (shdrs[i].sh_type == SHT_GNU_verdef) { verdef = &shdrs[i]; break; }
        }
        if (!verdef || verdef->sh_link >= eh->e_shnum) goto out;
        const Elf64_Shdr *strsh = &shdrs[verdef->sh_link];
        const char *strtab = (const char *)m + strsh->sh_offset;
        const char *vd_base = (const char *)m + verdef->sh_offset;
        const Elf64_Verdef *vd = (const Elf64_Verdef *)vd_base;
        size_t off = 0;
        while (off < verdef->sh_size) {
            const Elf64_Verdaux *aux = (const Elf64_Verdaux *)(vd_base + off + vd->vd_aux);
            const char *name = strtab + aux->vda_name;
            version_t v;
            if (parse_version_with_prefix(name, prefix, &v)) {
                if (version_cmp(&v, out) > 0) *out = v;
            }
            if (vd->vd_next == 0) break;
            off += vd->vd_next;
            vd = (const Elf64_Verdef *)(vd_base + off);
        }
        rc = 0;
    } else if (e_ident[EI_CLASS] == ELFCLASS32) {
        const Elf32_Ehdr *eh = (const Elf32_Ehdr *)m;
        if (eh->e_shoff == 0 || eh->e_shentsize < sizeof(Elf32_Shdr)) goto out;
        const Elf32_Shdr *shdrs = (const Elf32_Shdr *)((const char *)m + eh->e_shoff);
        const Elf32_Shdr *verdef = NULL;
        for (uint16_t i = 0; i < eh->e_shnum; i++) {
            if (shdrs[i].sh_type == SHT_GNU_verdef) { verdef = &shdrs[i]; break; }
        }
        if (!verdef || verdef->sh_link >= eh->e_shnum) goto out;
        const Elf32_Shdr *strsh = &shdrs[verdef->sh_link];
        const char *strtab = (const char *)m + strsh->sh_offset;
        const char *vd_base = (const char *)m + verdef->sh_offset;
        const Elf32_Verdef *vd = (const Elf32_Verdef *)vd_base;
        size_t off = 0;
        while (off < verdef->sh_size) {
            const Elf32_Verdaux *aux = (const Elf32_Verdaux *)(vd_base + off + vd->vd_aux);
            const char *name = strtab + aux->vda_name;
            version_t v;
            if (parse_version_with_prefix(name, prefix, &v)) {
                if (version_cmp(&v, out) > 0) *out = v;
            }
            if (vd->vd_next == 0) break;
            off += vd->vd_next;
            vd = (const Elf32_Verdef *)(vd_base + off);
        }
        rc = 0;
    }
out:
    munmap(m, (size_t)st.st_size);
    return rc;
}

/* ------------------------------------------------------------------------- */
/* Symlink helpers                                                           */
/* ------------------------------------------------------------------------- */

static int symlink_atomic(const char *target, const char *linkpath) {
    /* Replace existing link/file if any. */
    char tmp[PATH_MAX];
    snprintf(tmp, sizeof(tmp), "%s.tmp.%d", linkpath, (int)getpid());
    unlink(tmp);
    if (symlink(target, tmp) < 0) return -1;
    if (rename(tmp, linkpath) < 0) { int e = errno; unlink(tmp); errno = e; return -1; }
    return 0;
}

/* ------------------------------------------------------------------------- */
/* Manifest                                                                  */
/* ------------------------------------------------------------------------- */
/*
 * The manifest is a small text file in the cache directory:
 *
 *   VERSION 1
 *   HASH <config-hash>
 *   GLIBC_HOST <host-glibc-major>.<minor>.<patch>
 *   GLIBC_NIX <nix-glibc-major>.<minor>.<patch>
 *   LIBSTDCXX_HOST ...
 *   LIBSTDCXX_NIX ...
 *   USE_HOST_LOADER 0|1
 *   HOST_LD_SO <abs-path>
 *   LDSOCACHE_MTIME <secs.nsecs>
 *   LIB <soname> <abs-host-path> <mtime-secs.nsecs> <inode>
 *   LIB ...
 *   DRIVER_PATH <env-var> <abs-host-path>
 *   END
 */

typedef struct {
    int use_host_loader;
    char host_ld_so[PATH_MAX];
    /* Fully-built env values (already colon-joined), or NULL. */
    char *vk_driver_files;
    char *egl_vendor_files;
    char *driver_path_kv;  /* "ENV1=VAL1\nENV2=VAL2\n..." for non-symlinked driver paths */
    char *layer_paths_kv;  /* same format for layer dirs */
} cache_state_t;

static void cache_state_init(cache_state_t *c) {
    c->use_host_loader = 0;
    c->host_ld_so[0] = '\0';
    c->vk_driver_files = NULL;
    c->egl_vendor_files = NULL;
    c->driver_path_kv = NULL;
    c->layer_paths_kv = NULL;
}

static void cache_state_free(cache_state_t *c) {
    free(c->vk_driver_files);
    free(c->egl_vendor_files);
    free(c->driver_path_kv);
    free(c->layer_paths_kv);
    cache_state_init(c);
}

/* ------------------------------------------------------------------------- */
/* Cache validation                                                          */
/* ------------------------------------------------------------------------- */

/* Read the host's /etc/ld.so.cache mtime as "secs.nsecs" string in `out`. */
static int ldsocache_stamp(char *out, size_t outsz) {
    struct stat st;
    if (stat("/etc/ld.so.cache", &st) < 0) {
        snprintf(out, outsz, "0.0");
        return -1;
    }
    snprintf(out, outsz, "%lld.%09ld",
             (long long)st.st_mtim.tv_sec, st.st_mtim.tv_nsec);
    return 0;
}

/* Check whether `manifest` matches current host state. Returns 1 if valid. */
static int manifest_valid(const char *cache_dir, const char *config_hash) {
    char path[PATH_MAX];
    snprintf(path, sizeof(path), "%s/manifest", cache_dir);
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    int ok = 0;
    int saw_version = 0, saw_hash = 0, saw_stamp = 0;
    char ld_stamp_now[64];
    ldsocache_stamp(ld_stamp_now, sizeof(ld_stamp_now));

    char *line = NULL;
    size_t cap = 0;
    ssize_t n;
    while ((n = getline(&line, &cap, f)) > 0) {
        if (n > 0 && line[n-1] == '\n') line[n-1] = '\0';
        if (!strcmp(line, "VERSION 1")) saw_version = 1;
        else if (!strncmp(line, "HASH ", 5)) {
            if (!strcmp(line + 5, config_hash)) saw_hash = 1;
        } else if (!strncmp(line, "LDSOCACHE_MTIME ", 16)) {
            if (!strcmp(line + 16, ld_stamp_now)) saw_stamp = 1;
        } else if (!strncmp(line, "LIB ", 4)) {
            /* "LIB <soname> <path> <mtime> <inode>" */
            char *p = line + 4;
            char *soname = strsep(&p, " ");
            char *libpath = strsep(&p, " ");
            char *want_mtime = strsep(&p, " ");
            char *want_inode = strsep(&p, " ");
            (void)soname;
            if (!libpath || !want_mtime || !want_inode) { ok = 0; goto end; }
            struct stat st;
            if (stat(libpath, &st) < 0) { ok = 0; goto end; }
            char mt[64];
            snprintf(mt, sizeof(mt), "%lld.%09ld",
                     (long long)st.st_mtim.tv_sec, st.st_mtim.tv_nsec);
            if (strcmp(mt, want_mtime) != 0) { ok = 0; goto end; }
            char in[64];
            snprintf(in, sizeof(in), "%llu", (unsigned long long)st.st_ino);
            if (strcmp(in, want_inode) != 0) { ok = 0; goto end; }
        }
    }
    if (saw_version && saw_hash && saw_stamp) ok = 1;
end:
    free(line);
    fclose(f);
    return ok;
}

/* ------------------------------------------------------------------------- */
/* Cache build                                                               */
/* ------------------------------------------------------------------------- */

/* Append an entry to a colon-joined env value string (allocates / extends). */
static char *colon_append(char *cur, const char *piece) {
    if (!cur || !*cur) {
        free(cur);
        return strdup(piece);
    }
    size_t lc = strlen(cur), lp = strlen(piece);
    char *r = realloc(cur, lc + 1 + lp + 1);
    if (!r) { perror("realloc"); abort(); }
    r[lc] = ':';
    memcpy(r + lc + 1, piece, lp + 1);
    return r;
}

/* Append a manifest LIB line. */
static void manifest_emit_lib(FILE *f, const char *soname, const char *abspath) {
    struct stat st;
    if (stat(abspath, &st) < 0) return;
    fprintf(f, "LIB %s %s %lld.%09ld %llu\n",
            soname, abspath,
            (long long)st.st_mtim.tv_sec, st.st_mtim.tv_nsec,
            (unsigned long long)st.st_ino);
}

/* Build (or rebuild) the cache directory at `cache_dir` for the current host. */
static int cache_build(const char *cache_dir,
                       const char *config_hash,
                       cache_state_t *state) {
    /* 1. mkdir tmp; 2. fill it; 3. atomic rename. */
    char tmp[PATH_MAX];
    snprintf(tmp, sizeof(tmp), "%s.tmp.%d", cache_dir, (int)getpid());
    rmtree(tmp);
    if (mkdir_p(tmp, 0755) < 0) { wdp_warn("mkdir %s: %s", tmp, strerror(errno)); return -1; }

    char libdir[PATH_MAX];
    snprintf(libdir, sizeof(libdir), "%s/lib", tmp);
    if (mkdir_p(libdir, 0755) < 0) goto fail;

    /* Open ld.so.cache (best effort). */
    ldcache_t lc;
    int have_cache = (ldcache_open(&lc, "/etc/ld.so.cache") == 0);

    /* Manifest file. */
    char manifest_path[PATH_MAX];
    snprintf(manifest_path, sizeof(manifest_path), "%s/manifest", tmp);
    FILE *mf = fopen(manifest_path, "w");
    if (!mf) goto fail_cache;

    fprintf(mf, "VERSION 1\n");
    fprintf(mf, "HASH %s\n", config_hash);
    char ld_stamp[64];
    ldsocache_stamp(ld_stamp, sizeof(ld_stamp));
    fprintf(mf, "LDSOCACHE_MTIME %s\n", ld_stamp);

    /* Track host glibc / libstdc++ paths so we can compare versions later. */
    char host_libc[PATH_MAX] = {0};
    char host_libstdcxx[PATH_MAX] = {0};

    /* 1) Resolve and symlink each requested library. */
    for (size_t i = 0; i < WDP_LIBRARIES_N; i++) {
        const struct wdp_lib *L = &WDP_LIBRARIES[i];
        if (L->is_glob) {
            /* Globs aren't in ld.so.cache as patterns; scan FHS directly.
             * Also iterate ld.so.cache keys for matches. */
            size_t found_n = 0;
            char **found = fhs_lookup_glob(L->name, &found_n);
            /* Plus matches from ld.so.cache (helps on systems that store
             * non-FHS paths). */
            if (have_cache) {
                struct iter_ctx { const char *pat; char ***out; size_t *out_n; size_t *out_cap; };
                size_t cap = found_n;
                /* Closure-via-static-fn trick: iterate ourselves. */
                const struct file_entry_new *libs =
                    (const struct file_entry_new *)((const char *)lc.cf_new
                                                    + sizeof(struct cache_file_new));
                for (uint32_t j = 0; j < lc.cf_new->nlibs; j++) {
                    const char *key = lc.strtab + libs[j].key;
                    const char *val = lc.strtab + libs[j].value;
                    if (fnmatch(L->name, key, 0) != 0) continue;
                    if (!file_exists(val)) continue;
                    /* Dedup against found[]. */
                    int dup = 0;
                    for (size_t k = 0; k < found_n; k++) {
                        if (!strcmp(found[k], val)) { dup = 1; break; }
                    }
                    if (dup) continue;
                    if (found_n + 1 >= cap) {
                        cap = cap ? cap * 2 : 8;
                        found = realloc(found, cap * sizeof(*found));
                        if (!found) { perror("realloc"); abort(); }
                    }
                    found[found_n++] = strdup(val);
                }
                if (found) found[found_n] = NULL;
            }

            for (size_t k = 0; k < found_n; k++) {
                const char *src = found[k];
                const char *base = strrchr(src, '/');
                base = base ? base + 1 : src;
                char dst[PATH_MAX];
                snprintf(dst, sizeof(dst), "%s/%s", libdir, base);
                if (symlink_atomic(src, dst) == 0) {
                    manifest_emit_lib(mf, base, src);
                    wdp_log("glob %s -> %s", L->name, src);
                }
            }
            for (size_t k = 0; k < found_n; k++) free(found[k]);
            free(found);
        } else {
            /* Exact SONAME. */
            char *resolved = NULL;
            if (have_cache) {
                const char *p = ldcache_lookup(&lc, L->name);
                if (p && file_exists(p)) resolved = strdup(p);
            }
            if (!resolved) resolved = fhs_lookup_exact(L->name);
            if (!resolved) {
                wdp_log("not found on host: %s", L->name);
                continue;
            }
            char dst[PATH_MAX];
            snprintf(dst, sizeof(dst), "%s/%s", libdir, L->name);
            if (symlink_atomic(resolved, dst) == 0) {
                manifest_emit_lib(mf, L->name, resolved);
                wdp_log("%s -> %s", L->name, resolved);
                if (!strcmp(L->name, "libc.so.6")) snprintf(host_libc, sizeof(host_libc), "%s", resolved);
                if (!strcmp(L->name, "libstdc++.so.6")) snprintf(host_libstdcxx, sizeof(host_libstdcxx), "%s", resolved);
            }
            free(resolved);
        }
    }

    /* 2) Decide whether to use host or nix loader based on glibc version. */
    int use_host = 0;
    char host_ld_so[PATH_MAX] = {0};

    if (host_libc[0]) {
        version_t hv = {0}, nv = {0};
        elf_max_versym(host_libc, "GLIBC", &hv);
        if (WDP_NIX_LIBC && WDP_NIX_LIBC[0])
            elf_max_versym(WDP_NIX_LIBC, "GLIBC", &nv);
        fprintf(mf, "GLIBC_HOST %u.%u.%u\n", hv.major, hv.minor, hv.patch);
        fprintf(mf, "GLIBC_NIX %u.%u.%u\n", nv.major, nv.minor, nv.patch);
        if (version_cmp(&hv, &nv) > 0) use_host = 1;

        /* Find host's ld-linux. We try a few well-known names. */
        static const char *const ld_candidates[] = {
            "/lib64/ld-linux-x86-64.so.2",
            "/lib/ld-linux-x86-64.so.2",
            "/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2",
            "/lib/ld-linux-aarch64.so.1",
            "/lib64/ld-linux-aarch64.so.1",
            NULL,
        };
        for (size_t i = 0; ld_candidates[i]; i++) {
            if (file_exists(ld_candidates[i])) {
                snprintf(host_ld_so, sizeof(host_ld_so), "%s", ld_candidates[i]);
                break;
            }
        }
        if (!host_ld_so[0]) use_host = 0;  /* can't, fall back */
    }

    /* libstdc++ version compare (informational, plus may flip use_host) */
    if (host_libstdcxx[0]) {
        version_t hv = {0}, nv = {0};
        elf_max_versym(host_libstdcxx, "GLIBCXX", &hv);
        if (WDP_NIX_LIBSTDCXX && WDP_NIX_LIBSTDCXX[0])
            elf_max_versym(WDP_NIX_LIBSTDCXX, "GLIBCXX", &nv);
        fprintf(mf, "LIBSTDCXX_HOST %u.%u.%u\n", hv.major, hv.minor, hv.patch);
        fprintf(mf, "LIBSTDCXX_NIX %u.%u.%u\n", nv.major, nv.minor, nv.patch);
        /* If host libstdc++ is newer, our LD_LIBRARY_PATH already has it
         * first, so it gets picked up. No loader switch needed for it. */
    }

    fprintf(mf, "USE_HOST_LOADER %d\n", use_host);
    if (host_ld_so[0]) fprintf(mf, "HOST_LD_SO %s\n", host_ld_so);

    state->use_host_loader = use_host;
    if (host_ld_so[0]) snprintf(state->host_ld_so, sizeof(state->host_ld_so), "%s", host_ld_so);

    /* If we're not using the host loader, we should *not* have host libc
     * shadowing nix libc. Remove the libc-cohort symlinks. */
    if (!use_host) {
        static const char *const cohort[] = {
            "libc.so.6", "libdl.so.2", "libpthread.so.0", "libm.so.6",
            "librt.so.1", "libresolv.so.2", "libnsl.so.1", "libutil.so.1",
            "libcrypt.so.1", NULL,
        };
        for (size_t i = 0; cohort[i]; i++) {
            char p[PATH_MAX];
            snprintf(p, sizeof(p), "%s/%s", libdir, cohort[i]);
            unlink(p);
        }
    }

    /* 3) Mirror config dirs, build env strings. */
    for (size_t i = 0; i < WDP_CONFIGS_N; i++) {
        const struct wdp_cfg *C = &WDP_CONFIGS[i];
        char cache_subdir[PATH_MAX];
        snprintf(cache_subdir, sizeof(cache_subdir), "%s/%s", tmp, C->cache_subdir);
        if (mkdir_p(cache_subdir, 0755) < 0) continue;

        char *env_files = NULL;  /* colon-joined for mode=files */
        int wrote_anything = 0;
        for (size_t j = 0; j < C->source_dirs_n; j++) {
            const char *src_dir = C->source_dirs[j];
            DIR *d = opendir(src_dir);
            if (!d) continue;
            struct dirent *de;
            while ((de = readdir(d))) {
                if (de->d_name[0] == '.') continue;
                if (fnmatch(C->pattern, de->d_name, 0) != 0) continue;
                char src[PATH_MAX], dst[PATH_MAX];
                snprintf(src, sizeof(src), "%s/%s", src_dir, de->d_name);
                snprintf(dst, sizeof(dst), "%s/%s", cache_subdir, de->d_name);
                if (symlink_atomic(src, dst) == 0) {
                    wrote_anything = 1;
                    if (C->mode_dir == 0) env_files = colon_append(env_files, dst);
                    wdp_log("config %s -> %s", de->d_name, src);
                }
            }
            closedir(d);
        }
        if (wrote_anything) {
            const char *val = (C->mode_dir == 0) ? env_files : cache_subdir;
            for (size_t k = 0; k < C->env_vars_n; k++) {
                /* For Vulkan ICDs we set both VK_DRIVER_FILES and
                 * VK_ICD_FILENAMES. For all others we only honor the first
                 * env var that isn't already in our state map. */
                const char *ev = C->env_vars[k];
                /* layer_paths_kv aggregates every layer-style env */
                /* We just append all envs with their value, comma trick:
                 * record as "ENV=VAL\n". */
                size_t cur = state->layer_paths_kv ? strlen(state->layer_paths_kv) : 0;
                size_t need = strlen(ev) + 1 + strlen(val) + 2;
                state->layer_paths_kv = realloc(state->layer_paths_kv, cur + need);
                if (!state->layer_paths_kv) { perror("realloc"); abort(); }
                if (cur == 0) state->layer_paths_kv[0] = '\0';
                snprintf(state->layer_paths_kv + cur, need, "%s=%s\n", ev, val);
            }
            /* Special-case: keep separate fields for the most common ones
             * for clarity (also so debug logging is nicer). */
            if (C->mode_dir == 0) {
                if (C->env_vars_n > 0 && !strcmp(C->env_vars[0], "VK_DRIVER_FILES")) {
                    free(state->vk_driver_files);
                    state->vk_driver_files = strdup(env_files);
                }
                if (C->env_vars_n > 0 && !strcmp(C->env_vars[0], "__EGL_VENDOR_LIBRARY_FILENAMES")) {
                    free(state->egl_vendor_files);
                    state->egl_vendor_files = strdup(env_files);
                }
            }
        }
        free(env_files);
    }

    /* 4) Driver-module dirs (LIBGL_DRIVERS_PATH, LIBVA_DRIVERS_PATH, VDPAU_DRIVER_PATH) */
    for (size_t i = 0; i < WDP_DRIVER_PATHS_N; i++) {
        const struct wdp_drvpath *D = &WDP_DRIVER_PATHS[i];
        for (size_t j = 0; j < D->candidates_n; j++) {
            if (dir_exists(D->candidates[j])) {
                fprintf(mf, "DRIVER_PATH %s %s\n", D->env_var, D->candidates[j]);
                size_t cur = state->driver_path_kv ? strlen(state->driver_path_kv) : 0;
                size_t need = strlen(D->env_var) + 1 + strlen(D->candidates[j]) + 2;
                state->driver_path_kv = realloc(state->driver_path_kv, cur + need);
                if (!state->driver_path_kv) { perror("realloc"); abort(); }
                if (cur == 0) state->driver_path_kv[0] = '\0';
                snprintf(state->driver_path_kv + cur, need, "%s=%s\n",
                         D->env_var, D->candidates[j]);
                wdp_log("%s = %s", D->env_var, D->candidates[j]);
                break;
            }
        }
    }

    fprintf(mf, "END\n");
    fclose(mf);
    if (have_cache) ldcache_close(&lc);

    /* Atomic swap: rmtree old cache_dir, rename tmp -> cache_dir */
    rmtree(cache_dir);
    if (rename(tmp, cache_dir) < 0) {
        wdp_warn("rename %s -> %s: %s", tmp, cache_dir, strerror(errno));
        goto fail;
    }
    return 0;

fail_cache:
    if (have_cache) ldcache_close(&lc);
fail:
    rmtree(tmp);
    return -1;
}

/* ------------------------------------------------------------------------- */
/* Manifest read (when cache is already valid)                               */
/* ------------------------------------------------------------------------- */

static int manifest_read(const char *cache_dir, cache_state_t *state) {
    char path[PATH_MAX];
    snprintf(path, sizeof(path), "%s/manifest", cache_dir);
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    char *line = NULL;
    size_t cap = 0;
    ssize_t n;
    while ((n = getline(&line, &cap, f)) > 0) {
        if (n > 0 && line[n-1] == '\n') line[n-1] = '\0';
        if (!strncmp(line, "USE_HOST_LOADER ", 16)) {
            state->use_host_loader = atoi(line + 16);
        } else if (!strncmp(line, "HOST_LD_SO ", 11)) {
            snprintf(state->host_ld_so, sizeof(state->host_ld_so), "%s", line + 11);
        } else if (!strncmp(line, "DRIVER_PATH ", 12)) {
            char *p = line + 12;
            char *ev = strsep(&p, " ");
            if (ev && p) {
                size_t cur = state->driver_path_kv ? strlen(state->driver_path_kv) : 0;
                size_t need = strlen(ev) + 1 + strlen(p) + 2;
                state->driver_path_kv = realloc(state->driver_path_kv, cur + need);
                if (!state->driver_path_kv) { perror("realloc"); abort(); }
                if (cur == 0) state->driver_path_kv[0] = '\0';
                snprintf(state->driver_path_kv + cur, need, "%s=%s\n", ev, p);
            }
        }
    }
    free(line);
    fclose(f);

    /* Rebuild VK / EGL env strings by scanning cache dir on read. */
    char vk_dir[PATH_MAX], egl_dir[PATH_MAX];
    snprintf(vk_dir, sizeof(vk_dir), "%s/share/vulkan/icd.d", cache_dir);
    snprintf(egl_dir, sizeof(egl_dir), "%s/share/glvnd/egl_vendor.d", cache_dir);

    for (int which = 0; which < 2; which++) {
        const char *d = which == 0 ? vk_dir : egl_dir;
        DIR *dh = opendir(d);
        if (!dh) continue;
        struct dirent *de;
        char *acc = NULL;
        while ((de = readdir(dh))) {
            if (de->d_name[0] == '.') continue;
            char full[PATH_MAX];
            snprintf(full, sizeof(full), "%s/%s", d, de->d_name);
            acc = colon_append(acc, full);
        }
        closedir(dh);
        if (which == 0) state->vk_driver_files = acc;
        else state->egl_vendor_files = acc;
    }

    /* layer_paths_kv: rebuild from manifest is unnecessary because we
     * primarily need it for vk layers; skip on read for now. */
    return 0;
}

/* ------------------------------------------------------------------------- */
/* Env helpers                                                               */
/* ------------------------------------------------------------------------- */

static void env_prepend_path(const char *name, const char *value) {
    const char *cur = getenv(name);
    if (cur && *cur) {
        char *combined;
        if (asprintf(&combined, "%s:%s", value, cur) < 0) return;
        setenv(name, combined, 1);
        free(combined);
    } else {
        setenv(name, value, 1);
    }
}

/* Set name=value lines from a "KEY=VAL\n..." buffer, prepending colon-style
 * paths if the value names a directory env. We do simple set-or-prepend:
 * if KEY already exists, we *prepend* to it for path-like vars (XDG_DATA_DIRS,
 * VK_LAYER_PATH, ...), otherwise we just setenv. */
static void apply_kv_block(const char *kv) {
    if (!kv) return;
    const char *p = kv;
    while (*p) {
        const char *nl = strchr(p, '\n');
        size_t linelen = nl ? (size_t)(nl - p) : strlen(p);
        if (linelen > 0) {
            char buf[PATH_MAX * 2];
            if (linelen >= sizeof(buf)) linelen = sizeof(buf) - 1;
            memcpy(buf, p, linelen);
            buf[linelen] = '\0';
            char *eq = strchr(buf, '=');
            if (eq) {
                *eq = '\0';
                const char *name = buf;
                const char *val = eq + 1;
                /* For known path-list vars, prepend; otherwise set. */
                if (!strcmp(name, "XDG_DATA_DIRS")
                    || !strcmp(name, "VK_LAYER_PATH")
                    || !strcmp(name, "VK_IMPLICIT_LAYER_PATH")) {
                    env_prepend_path(name, val);
                } else {
                    setenv(name, val, 1);
                }
            }
        }
        if (!nl) break;
        p = nl + 1;
    }
}

/* ------------------------------------------------------------------------- */
/* Entry point                                                               */
/* ------------------------------------------------------------------------- */

static int run_program(int argc, char **argv, const cache_state_t *state) {
    /* Build argv for execv. */
    if (state->use_host_loader && state->host_ld_so[0]) {
        /* exec: <ld.so> --argv0 argv[0] <real-prog> argv[1..] */
        char **nv = calloc((size_t)argc + 4, sizeof(char *));
        if (!nv) { perror("calloc"); return 127; }
        size_t k = 0;
        nv[k++] = (char *)state->host_ld_so;
        nv[k++] = (char *)"--argv0";
        nv[k++] = argv[0];
        nv[k++] = (char *)WDP_REAL_PROGRAM;
        for (int i = 1; i < argc; i++) nv[k++] = argv[i];
        nv[k] = NULL;
        execv(state->host_ld_so, nv);
        /* Older ld.so doesn't grok --argv0 -> retry without it. */
        if (errno == EINVAL || errno == ENOEXEC) {
            k = 0;
            nv[k++] = (char *)state->host_ld_so;
            nv[k++] = (char *)WDP_REAL_PROGRAM;
            for (int i = 1; i < argc; i++) nv[k++] = argv[i];
            nv[k] = NULL;
            execv(state->host_ld_so, nv);
        }
        wdp_warn("execv host ld.so %s: %s", state->host_ld_so, strerror(errno));
        free(nv);
        /* fall through to direct exec */
    }

    /* Direct exec of the real program. */
    char **nv = calloc((size_t)argc + 1, sizeof(char *));
    if (!nv) { perror("calloc"); return 127; }
    nv[0] = argv[0];
    for (int i = 1; i < argc; i++) nv[i] = argv[i];
    nv[argc] = NULL;
    execv(WDP_REAL_PROGRAM, nv);
    wdp_warn("execv %s: %s", WDP_REAL_PROGRAM, strerror(errno));
    return 127;
}

int main(int argc, char **argv) {
    const char *dbg = getenv("NIX_DRIVER_WRAP_DEBUG");
    if (dbg && *dbg && strcmp(dbg, "0") != 0) wdp_debug = 1;

    /* Opt-out: NIX_DRIVER_WRAP_DISABLE=1 */
    const char *disable = getenv("NIX_DRIVER_WRAP_DISABLE");
    if (disable && *disable && strcmp(disable, "0") != 0) {
        execv(WDP_REAL_PROGRAM, argv);
        perror(WDP_REAL_PROGRAM);
        return 127;
    }

    /* NixOS fast path. */
    if (dir_exists("/run/opengl-driver/lib")) {
        wdp_log("NixOS fast path");
        env_prepend_path("LD_LIBRARY_PATH", "/run/opengl-driver/lib");
        if (dir_exists("/run/opengl-driver-32/lib"))
            env_prepend_path("LD_LIBRARY_PATH", "/run/opengl-driver-32/lib");
        execv(WDP_REAL_PROGRAM, argv);
        perror(WDP_REAL_PROGRAM);
        return 127;
    }

    /* Resolve cache dir. */
    char cache_dir[PATH_MAX];
    const char *xdg = getenv("XDG_CACHE_HOME");
    if (xdg && *xdg) {
        snprintf(cache_dir, sizeof(cache_dir), "%s/nix-driver-wrap/%s", xdg, WDP_CONFIG_HASH);
    } else {
        const char *home = getenv("HOME");
        if (!home) {
            wdp_warn("no HOME or XDG_CACHE_HOME set; running without driver shim");
            execv(WDP_REAL_PROGRAM, argv);
            perror(WDP_REAL_PROGRAM);
            return 127;
        }
        snprintf(cache_dir, sizeof(cache_dir), "%s/.cache/nix-driver-wrap/%s", home, WDP_CONFIG_HASH);
    }

    cache_state_t state;
    cache_state_init(&state);

    if (!manifest_valid(cache_dir, WDP_CONFIG_HASH)) {
        wdp_log("(re)building cache at %s", cache_dir);
        if (cache_build(cache_dir, WDP_CONFIG_HASH, &state) < 0) {
            wdp_warn("cache build failed; running without driver shim");
            execv(WDP_REAL_PROGRAM, argv);
            perror(WDP_REAL_PROGRAM);
            return 127;
        }
    } else {
        wdp_log("using cache at %s", cache_dir);
        if (manifest_read(cache_dir, &state) < 0) {
            wdp_warn("manifest read failed; rebuilding");
            cache_state_free(&state);
            cache_state_init(&state);
            if (cache_build(cache_dir, WDP_CONFIG_HASH, &state) < 0) {
                execv(WDP_REAL_PROGRAM, argv);
                perror(WDP_REAL_PROGRAM);
                return 127;
            }
        }
    }

    /* LD_LIBRARY_PATH = <cache>/lib : existing */
    char libdir[PATH_MAX];
    snprintf(libdir, sizeof(libdir), "%s/lib", cache_dir);
    env_prepend_path("LD_LIBRARY_PATH", libdir);

    /* Vulkan ICDs */
    if (state.vk_driver_files && *state.vk_driver_files) {
        setenv("VK_DRIVER_FILES", state.vk_driver_files, 1);
        setenv("VK_ICD_FILENAMES", state.vk_driver_files, 1);
    }
    /* EGL vendor */
    if (state.egl_vendor_files && *state.egl_vendor_files) {
        setenv("__EGL_VENDOR_LIBRARY_FILENAMES", state.egl_vendor_files, 1);
    }
    /* OCL_ICD_VENDORS, layer paths */
    apply_kv_block(state.layer_paths_kv);
    /* Driver module dirs */
    apply_kv_block(state.driver_path_kv);

    int rc = run_program(argc, argv, &state);
    cache_state_free(&state);
    return rc;
}

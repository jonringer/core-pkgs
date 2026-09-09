{ lib }:
# Declarative list of host-provided "driver" / hardware-acceleration libraries
# and configuration directories that wrapDriverProgram should attempt to expose
# from the host system to a nix-built executable.
#
# Each entry in `libraries` is a SONAME (or globbed SONAME) that the wrapper's
# C launcher will try to resolve via /etc/ld.so.cache (and a small set of
# fallback FHS paths) on the host system. Resolved entries are symlinked
# into a per-user cache directory and added to LD_LIBRARY_PATH.
#
# Each entry in `configs` describes a host configuration directory whose
# contents (typically vendor JSON files) should be mirrored into the cache and
# pointed at via well-known environment variables.
#
# Each entry in `driverPaths` describes a host directory containing
# loadable driver modules (e.g. DRI, VAAPI, VDPAU). When a host directory
# matching the candidates is found, the corresponding env var is set to it
# directly (we do not symlink the whole directory because drivers often
# load sibling files by relative path).

let
  # Helper: turn a list of plain SONAMEs into the structure used below.
  soname = name: {
    inherit name;
    glob = false;
  };
  # Helper: a glob pattern (e.g. libnvidia-*.so.*). The wrapper resolves
  # globs against ldconfig output and the fallback FHS lib dirs.
  globSoname = name: {
    inherit name;
    glob = true;
  };
in
{
  # Libraries we attempt to symlink from host -> cache and add to LD_LIBRARY_PATH.
  libraries = [
    # ---- glibc cohort (used for newer-glibc-wins detection / loader swap) ----
    # These are special: the wrapper records their host vs. nix versions and
    # decides whether to exec via the host ld-linux loader.
    (soname "libc.so.6")
    (soname "libdl.so.2")
    (soname "libpthread.so.0")
    (soname "libm.so.6")
    (soname "librt.so.1")
    (soname "libresolv.so.2")
    (soname "libnsl.so.1")
    (soname "libutil.so.1")
    (soname "libcrypt.so.1")
    # libstdc++ uses the same newer-wins logic to avoid GLIBCXX symbol misses.
    (soname "libstdc++.so.6")
    (soname "libgcc_s.so.1")

    # ---- libglvnd / OpenGL dispatch ----
    (soname "libGL.so.1")
    (soname "libGLX.so.0")
    (soname "libEGL.so.1")
    (soname "libGLdispatch.so.0")
    (soname "libGLESv1_CM.so.1")
    (soname "libGLESv2.so.2")
    (soname "libOpenGL.so.0")
    (soname "libGLU.so.1")

    # ---- Vulkan ----
    (soname "libvulkan.so.1")

    # ---- OpenCL ICD loader ----
    (soname "libOpenCL.so.1")

    # ---- DRM / GBM ----
    (soname "libdrm.so.2")
    (soname "libgbm.so.1")
    (globSoname "libdrm_amdgpu.so.*")
    (globSoname "libdrm_radeon.so.*")
    (globSoname "libdrm_nouveau.so.*")
    (globSoname "libdrm_intel.so.*")
    (globSoname "libdrm_freedreno.so.*")
    (globSoname "libdrm_tegra.so.*")

    # ---- VAAPI ----
    (soname "libva.so.2")
    (soname "libva-drm.so.2")
    (soname "libva-x11.so.2")
    (soname "libva-wayland.so.2")
    (soname "libva-glx.so.2")

    # ---- VDPAU ----
    (soname "libvdpau.so.1")

    # ---- NVIDIA proprietary ----
    (soname "libcuda.so.1")
    (soname "libcudadebugger.so.1")
    (soname "libnvidia-ml.so.1")
    (soname "libnvcuvid.so.1")
    (soname "libnvidia-encode.so.1")
    (soname "libnvidia-decode.so.1")
    (soname "libnvidia-opencl.so.1")
    (soname "libnvidia-opticalflow.so.1")
    (soname "libnvidia-ptxjitcompiler.so.1")
    (soname "libnvidia-allocator.so.1")
    (soname "libnvidia-cfg.so.1")
    (soname "libnvidia-fbc.so.1")
    (soname "libnvidia-nvvm.so.4")
    (soname "libnvoptix.so.1")
    (globSoname "libnvidia-*.so.*")
    (globSoname "libnvoptix.so.*")
    (globSoname "libnvidia-tls.so.*")
    (globSoname "libnvidia-glcore.so.*")
    (globSoname "libnvidia-glsi.so.*")
    (globSoname "libnvidia-eglcore.so.*")
    (globSoname "libnvidia-rtcore.so.*")
    (globSoname "libnvidia-fatbinaryloader.so.*")
    (globSoname "libnvidia-glvkspirv.so.*")
    (globSoname "libnvidia-pkcs11*.so.*")

    # ---- Misc CUDA / system-provided NVIDIA-adjacent ----
    (globSoname "libnvJitLink.so.*")
    (globSoname "libnvrtc.so.*")
    (globSoname "libnvrtc-builtins.so.*")
    (soname "libnvToolsExt.so.1")

    # ---- ROCm / AMD compute (best-effort, only used if present on host) ----
    (globSoname "libhsa-runtime64.so.*")
    (globSoname "libamd_comgr.so.*")
    (globSoname "librocm_smi64.so.*")
    (globSoname "libhsakmt.so.*")

    # ---- NUMA (often pulled in transitively by HPC/CUDA libs) ----
    (soname "libnuma.so.1")
  ];

  # Configuration directories whose contents (file globs) we mirror into the
  # cache. The wrapper sets the corresponding env var to a colon-joined list
  # of the symlinked file paths or the cache directory.
  configs = [
    {
      # Vulkan ICDs (drivers)
      sourceDirs = [
        "/usr/share/vulkan/icd.d"
        "/usr/local/share/vulkan/icd.d"
        "/etc/vulkan/icd.d"
      ];
      pattern = "*.json";
      cacheSubdir = "share/vulkan/icd.d";
      # Set both the modern and legacy variable names.
      envVars = [
        "VK_DRIVER_FILES"
        "VK_ICD_FILENAMES"
      ];
      # Mode: "files" -> env var = colon-joined file paths;
      #       "dir"   -> env var = directory path.
      mode = "files";
    }
    {
      # Vulkan explicit layers
      sourceDirs = [
        "/usr/share/vulkan/explicit_layer.d"
        "/usr/local/share/vulkan/explicit_layer.d"
        "/etc/vulkan/explicit_layer.d"
      ];
      pattern = "*.json";
      cacheSubdir = "share/vulkan/explicit_layer.d";
      envVars = [ "VK_LAYER_PATH" ];
      mode = "dir";
    }
    {
      # Vulkan implicit layers
      sourceDirs = [
        "/usr/share/vulkan/implicit_layer.d"
        "/usr/local/share/vulkan/implicit_layer.d"
        "/etc/vulkan/implicit_layer.d"
      ];
      pattern = "*.json";
      cacheSubdir = "share/vulkan/implicit_layer.d";
      envVars = [
        "VK_IMPLICIT_LAYER_PATH"
        "XDG_DATA_DIRS"
      ];
      mode = "dir";
    }
    {
      # GLVND EGL vendor configs
      sourceDirs = [
        "/usr/share/glvnd/egl_vendor.d"
        "/etc/glvnd/egl_vendor.d"
      ];
      pattern = "*.json";
      cacheSubdir = "share/glvnd/egl_vendor.d";
      envVars = [ "__EGL_VENDOR_LIBRARY_FILENAMES" ];
      mode = "files";
    }
    {
      # OpenCL vendors
      sourceDirs = [
        "/etc/OpenCL/vendors"
        "/usr/etc/OpenCL/vendors"
      ];
      pattern = "*.icd";
      cacheSubdir = "etc/OpenCL/vendors";
      envVars = [ "OCL_ICD_VENDORS" ];
      mode = "dir";
    }
  ];

  # Host driver-module directories. We don't symlink these; if a candidate
  # exists, the wrapper sets the env var directly to that host path so the
  # drivers can find their sibling files unmolested.
  driverPaths = [
    {
      # DRI drivers (Mesa)
      candidates = [
        "/usr/lib/x86_64-linux-gnu/dri"
        "/usr/lib64/dri"
        "/usr/lib/dri"
      ];
      envVar = "LIBGL_DRIVERS_PATH";
    }
    {
      # VAAPI drivers
      candidates = [
        "/usr/lib/x86_64-linux-gnu/dri"
        "/usr/lib64/dri"
        "/usr/lib/dri"
      ];
      envVar = "LIBVA_DRIVERS_PATH";
    }
    {
      # VDPAU drivers
      candidates = [
        "/usr/lib/x86_64-linux-gnu/vdpau"
        "/usr/lib64/vdpau"
        "/usr/lib/vdpau"
      ];
      envVar = "VDPAU_DRIVER_PATH";
    }
  ];
}

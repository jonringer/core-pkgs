{
  stdenv,
  lib,
  fetchFromGitHub,
  autoreconfHook,
  go-md2man,
  pkg-config,
  libcap,
  libseccomp,
  python3,
  systemdMinimal,
  json_c,
  testers,
}:

let
  # these tests require additional permissions
  disabledTests = [
    "test_capabilities.py"
    "test_cwd.py"
    "test_delete.py"
    "test_detach.py"
    "test_exec.py"
    "test_hooks.py"
    "test_hostname.py"
    "test_oci_features"
    "test_paths.py"
    "test_pid.py"
    "test_pid_file.py"
    "test_preserve_fds.py"
    "test_resources"
    "test_seccomp"
    "test_start.py"
    "test_uid_gid.py"
    "test_update.py"
    "tests_libcrun_utils"
  ];

in
stdenv.mkDerivation (finalAttrs: {
  pname = "crun";
  version = "1.29.1";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "crun";
    tag = finalAttrs.version;
    hash = "sha256-KmwkiExekHozW84dmkcC8OW8AP11Fsqj2t/n+ZGXpB4=";
    fetchSubmodules = true;
    leaveDotGit = true;
    postFetch = ''
      cd $out
      git rev-parse HEAD > COMMIT
      rm -rf .git
    '';
  };

  nativeBuildInputs = [
    autoreconfHook
    go-md2man
    pkg-config
    python3
  ];

  buildInputs = [
    libcap
    libseccomp
    systemdMinimal
    json_c
  ];

  enableParallelBuilding = true;
  strictDeps = true;

  # we need this before autoreconfHook does its thing in order to initialize
  # config.h with the correct values
  postPatch = ''
    echo ${finalAttrs.version} > .tarball-version
    echo "#define GIT_VERSION \"$(cat COMMIT)\"" > git-version.h

    ${lib.concatMapStringsSep "\n" (
      e: "substituteInPlace Makefile.am --replace-fail 'tests/${e}' ''"
    ) disabledTests}
  '';

  doCheck = false;

  passthru.tests = {
    version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "crun --version";
    };
  };

  meta = {
    description = "Fast and lightweight fully featured OCI runtime and C library for running containers";
    homepage = "https://github.com/containers/crun";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "crun";
    identifiers.cpeParts = lib.meta.cpeFullVersionWithVendor "crun_project" finalAttrs.version;
  };
})

{ cctools }:
rec {
  unwrapped-all-targets = v2_44 // {
    variant = "unwrapped-all-targets";
    unwrapped = true;
    withAllTargets = true;
  };
  v2_44 = {
    variant = "v2_44";
    implementation = "upstream";
    unwrapped = false;
    withAllTargets = false;
    version = "2.44";
    hash = "sha256-NHM+pJXMDlDnDbTliQ3sKKxB8OFMShZeac8n+5moxMg=";
  };
  v2_38 = {
    variant = "v2_38";
    implementation = "legacy";
    unwrapped = false;
    withAllTargets = false;
    version = "2.38";
    hash = "sha256-Bw7HHPB3pqWOC5WfBaCaNQFTeMLYpR6Q866r/jBZDvg=";
  };
  darwin = {
    variant = "darwin";
    implementation = "darwin";
    unwrapped = false;
    withAllTargets = false;
    version = cctools.version;
  };
}

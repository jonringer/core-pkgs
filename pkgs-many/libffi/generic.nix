{
  implementation ? "upstream",
  ...
}@variantArgs:
if implementation == "darwin" then import ./darwin.nix else import ./upstream.nix variantArgs

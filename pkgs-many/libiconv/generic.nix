{
  implementation ? "upstream",
  ...
}@variantArgs:
if implementation == "darwin" then
  import ./darwin.nix
else if implementation == "libc" then
  import ./libc.nix
else
  import ./upstream.nix variantArgs

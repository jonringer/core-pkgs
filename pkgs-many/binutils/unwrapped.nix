{ implementation, ... }@variantArgs:
if implementation == "darwin" then
  import ./darwin.nix
else if implementation == "legacy" then
  import ./2.38 variantArgs
else
  import ./upstream.nix variantArgs

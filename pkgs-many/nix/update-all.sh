#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash nix-update jq

set -xeuo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(readlink -f "$SCRIPT_DIR/../..")
cd "$REPO_DIR"

nix_versions=$(nix eval --impure --json --expr "with import ./. { config.aliases.nixpkgs = false; }; builtins.filter (name: builtins.match \"v2_.*\" name != null) (builtins.attrNames nix.variants)" | jq -r '.[]')

for name in $nix_versions; do
    minor_version=${name#v*_}

    nix-update --override-filename "$SCRIPT_DIR/variants.nix" --version-regex "(2\\.${minor_version}\..+)" --build --commit "nix.$name"
done

stable_version_full=$(nix eval --impure --json --expr "with import ./. { config.aliases.nixpkgs = false; }; nix.stable.version" | jq -r)

# strip patch version
stable_version_trimmed=${stable_version_full%.*}

for name in $nix_versions; do
    minor_version=${name#v*_}
    if [[ "$name" = "v${stable_version_trimmed//./_}" ]]; then
        curl https://releases.nixos.org/nix/nix-$stable_version_full/fallback-paths.nix > "$REPO_DIR/nixos/modules/installer/tools/nix-fallback-paths.nix"
        # nix-update will commit the file if it has changed
        git add "$REPO_DIR/nixos/modules/installer/tools/nix-fallback-paths.nix"
        git commit -m "nix: update nix-fallback-paths to $stable_version_full"
        break
    fi
done

commit_json=$(curl -s https://api.github.com/repos/NixOS/nix/commits/master) # format: 2024-11-01T10:18:53Z
date_of_commit=$(echo "$commit_json" | jq -r '.commit.author.date')
suffix="pre$(date -d "$date_of_commit" +%Y%m%d)"
sed -i -e "s|\"pre[0-9]\{8\}|\"$suffix|g" "$SCRIPT_DIR/variants.nix"
nix-update --override-filename "$SCRIPT_DIR/variants.nix" --version branch --build --commit "nix.git"

"""The rewrite vocabulary, read from the package set's own alias files.

corepkgs already records how it spells upstream names, in `aliases/nixpkgs.nix`
and `python/aliases.nix`. Reading those at run time means the sync tool cannot
drift from the aliases the package set actually defines -- a hand-copied list
would.

Not every alias is a useful rewrite. Most of `aliases.nix` mirrors nixpkgs' own
aliases, so both trees already write the same name and rewriting would invent a
diff rather than remove one. Those are named in `config.ALIAS_EXCLUSIONS`.
"""

import re
from pathlib import Path

from . import config

# `  name = target;` at the two-space indent `aliases.nix` uses for entries.
_ALIAS = re.compile(r"^ {2}([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*([^;]+);\s*$")

# Removals and conditionals are not renames.
_NOT_A_RENAME = ("throw", "if", "lib.warn", "builtins", "abort")

_START = "keep-sorted start"
_END = "keep-sorted end"


def parse(text: str) -> dict[str, str]:
    """Extract `name -> target` pairs from an alias file's keep-sorted block.

    Only the block is read. Everything above it is the `mapAliases` scaffolding,
    which is not a list of aliases and must not be mistaken for one.
    """
    try:
        block = text[text.index(_START) : text.index(_END)]
    except ValueError:
        return {}

    found: dict[str, str] = {}
    for line in block.splitlines():
        match = _ALIAS.match(line)
        if match is None:
            continue
        name, target = match.group(1), match.group(2).strip()
        if target.startswith(_NOT_A_RENAME):
            continue
        found[name] = target
    return found


def load(corepkgs_root: Path) -> list[tuple[re.Pattern[str], str]]:
    """Build the rewrite vocabulary for a corepkgs checkout.

    Returns compiled `(pattern, replacement)` pairs: the alias files' entries
    minus the exclusions, plus the renames no alias can express.
    """
    vocabulary: list[tuple[re.Pattern[str], str]] = []

    for relative in config.ALIAS_FILES:
        path = corepkgs_root / relative
        if not path.is_file():
            continue
        for name, target in parse(path.read_text(encoding="utf-8")).items():
            if name in config.ALIAS_EXCLUSIONS:
                continue
            vocabulary.append((re.compile(rf"\b{re.escape(name)}\b"), target))

    for pattern, replacement in config.EXTRA_VOCABULARY:
        vocabulary.append((re.compile(pattern), replacement))

    return vocabulary

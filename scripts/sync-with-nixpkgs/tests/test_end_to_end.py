from syncnix import cli, config, survey


def _generate(trees, *extra):
    return cli.main(
        ["--corepkgs", str(trees.root), "--nixpkgs", str(trees.upstream), "generate", *extra]
    )


def _accept(trees, *targets):
    return cli.main(
        ["--corepkgs", str(trees.root), "--nixpkgs", str(trees.upstream), "accept", *targets]
    )


def _patches(trees):
    return trees.root / config.PATCHES_DIR


class TestSurvey:
    def test_identical_files_produce_no_patch(self, trees):
        trees.pair("same\n", "same\n"
        )
        result = survey.run(trees.root, trees.upstream)
        assert result.patches == {}
        assert result.identical == 1

    def test_differing_files_produce_one_grouped_patch(self, trees):
        trees.pair("a\n", "b\n")
        trees.both("pkgs/curl/extra.nix", "pkgs/by-name/cu/curl/extra.nix", "c\n", "d\n")
        result = survey.run(trees.root, trees.upstream)
        assert list(result.patches) == ["pkgs/curl.patch"]
        assert "extra.nix" in result.patches["pkgs/curl.patch"]

    def test_unmapped_file_is_reported_not_diffed(self, trees):
        trees.local("unclaimed/thing.nix", "x\n")
        result = survey.run(trees.root, trees.upstream)
        assert result.unmapped == ["unclaimed/thing.nix"]
        assert result.patches == {}

    def test_file_absent_upstream_is_reported_as_missing(self, trees):
        trees.local("pkgs/only-here/default.nix", "x\n")
        result = survey.run(trees.root, trees.upstream)
        assert result.missing == ["pkgs/only-here/default.nix"]

    def test_markdown_is_never_compared(self, trees):
        trees.both(
            "pkgs/curl/README.md", "pkgs/by-name/cu/curl/README.md", "ours\n", "theirs\n"
        )
        result = survey.run(trees.root, trees.upstream)
        assert result.patches == {}
        assert result.unmapped == []
        assert result.missing == []

    def test_ignored_tree_is_not_walked(self, trees):
        trees.local("scripts/whatever.py", "x\n")
        result = survey.run(trees.root, trees.upstream)
        assert result.unmapped == []
        assert result.missing == []


class TestOpaqueFiles:
    def test_patch_file_contents_never_reach_the_output(self, trees):
        trees.pair("a\n", "b\n")
        trees.both(
            "pkgs/curl/fix.patch",
            "pkgs/by-name/cu/curl/fix.patch",
            "--- a/upstream.c\n+++ b/upstream.c\n@@ -1 +1 @@\n-old\n+new\n",
            "--- a/upstream.c\n+++ b/upstream.c\n@@ -1 +1 @@\n-old\n+DIFFERENT\n",
        )
        result = survey.run(trees.root, trees.upstream)
        body = result.patches["pkgs/curl.patch"]

        assert "DIFFERENT" not in body
        assert "upstream.c" not in body
        assert "pkgs/curl/fix.patch <- pkgs/by-name/cu/curl/fix.patch" in body
        assert result.opaque_differs == ["pkgs/curl/fix.patch"]

    def test_identical_patch_file_is_silent(self, trees):
        trees.both("pkgs/curl/fix.patch", "pkgs/by-name/cu/curl/fix.patch", "same\n", "same\n")
        result = survey.run(trees.root, trees.upstream)
        assert result.patches == {}
        assert result.opaque_differs == []


class TestBaselineWorkflow:
    def _diverge(self, trees):
        trees.pair("a\n", "b\n")

    def test_generate_writes_patches_and_reports(self, trees, capsys):
        self._diverge(trees)
        assert _generate(trees) == 0
        assert (_patches(trees) / "pkgs" / "curl.patch").is_file()
        assert "new divergence" in capsys.readouterr().out

    def test_strict_fails_on_unaccepted_drift(self, trees):
        self._diverge(trees)
        assert _generate(trees, "--strict") == 1

    def test_accepted_divergence_stops_being_drift(self, trees):
        self._diverge(trees)
        _accept(trees)
        assert _generate(trees, "--strict") == 0

    def test_changed_divergence_resurfaces(self, trees, capsys):
        self._diverge(trees)
        _accept(trees)
        trees.repoint("something else\n")
        assert _generate(trees, "--strict") == 1
        assert "changed vs accepted" in capsys.readouterr().out

    def test_accepted_divergence_is_not_duplicated_into_patches(self, trees):
        # The accepted patch is already stored byte for byte under ACCEPTED_DIR.
        self._diverge(trees)
        _accept(trees)
        _generate(trees)
        assert not (_patches(trees) / "pkgs" / "curl.patch").exists()
        assert (trees.root / config.ACCEPTED_DIR / "pkgs" / "curl.patch").is_file()

    def test_drift_from_the_baseline_is_written_again(self, trees):
        self._diverge(trees)
        _accept(trees)
        trees.repoint("something else\n")
        _generate(trees)
        # No longer matches what was accepted, so it needs reading.
        assert (_patches(trees) / "pkgs" / "curl.patch").is_file()

    def test_an_unaccepted_sibling_is_still_written(self, trees):
        self._diverge(trees)
        trees.pair("a\n", "b\n", package="jq")
        _accept(trees, "pkgs/curl.patch")
        _generate(trees)
        assert not (_patches(trees) / "pkgs" / "curl.patch").exists()
        assert (_patches(trees) / "pkgs" / "jq.patch").is_file()

    def test_resolved_divergence_is_flagged_as_stale(self, trees, capsys):
        self._diverge(trees)
        _accept(trees)
        trees.repoint("a\n")
        _generate(trees)
        out = capsys.readouterr().out
        assert "resolved, baseline is stale" in out
        assert "pkgs/curl.patch" in out

    def test_accept_can_target_one_patch(self, trees):
        self._diverge(trees)
        trees.pair("a\n", "b\n", package="jq")
        _accept(trees, "pkgs/curl.patch")
        assert _generate(trees, "--strict") == 1

    def test_accept_forgets_stale_entries(self, trees):
        self._diverge(trees)
        _accept(trees)
        trees.repoint("a\n")
        _accept(trees, "pkgs/curl.patch")
        assert _generate(trees, "--strict") == 0

    def test_dry_run_writes_nothing(self, trees):
        self._diverge(trees)
        _generate(trees, "--dry-run")
        assert not _patches(trees).exists()

    def test_generate_refreshes_stale_patch_files(self, trees):
        self._diverge(trees)
        _generate(trees)
        stale = _patches(trees) / "pkgs" / "stale.patch"
        stale.write_text("leftover\n", encoding="utf-8")
        _generate(trees)
        assert not stale.exists()


class TestReports:
    def test_unmapped_paths_are_written_out(self, trees):
        trees.local("unclaimed/thing.nix", "x\n")
        _generate(trees)
        report = _patches(trees) / config.REPORTS_DIR / "unmapped-paths.txt"
        assert "unclaimed/thing.nix" in report.read_text(encoding="utf-8")

    def test_no_report_is_written_when_nothing_to_say(self, trees):
        trees.pair("same\n", "same\n"
        )
        _generate(trees)
        assert not (_patches(trees) / config.REPORTS_DIR).exists()


class TestRoots:
    def test_missing_nixpkgs_exits_with_a_message(self, trees, capsys):
        import pytest

        with pytest.raises(SystemExit) as exit_info:
            cli.main(
                ["--corepkgs", str(trees.root), "--nixpkgs", str(trees.root / "nope"), "generate"]
            )
        assert "nixpkgs directory not found" in str(exit_info.value)

    def test_roots_are_validated_before_patches_are_deleted(self, trees):
        self_patches = _patches(trees)
        self_patches.mkdir(parents=True)
        (self_patches / "keep.patch").write_text("kept\n", encoding="utf-8")

        import pytest

        with pytest.raises(SystemExit):
            cli.main(
                ["--corepkgs", str(trees.root), "--nixpkgs", str(trees.root / "nope"), "generate"]
            )
        assert (self_patches / "keep.patch").is_file()


class TestLocalOnly:
    """Files corepkgs carries that nixpkgs has no counterpart for."""

    def test_declared_file_is_counted_not_reported_missing(self, trees, monkeypatch):
        monkeypatch.setattr(config, "LOCAL_ONLY", ["pkgs/only-here"])
        trees.local("pkgs/only-here/default.nix", "x\n")
        result = survey.run(trees.root, trees.upstream)
        assert result.missing == []
        assert result.local_only == 1

    def test_declared_but_unmapped_file_is_still_counted(self, trees, monkeypatch):
        monkeypatch.setattr(config, "LOCAL_ONLY", ["unclaimed"])
        trees.local("unclaimed/thing.nix", "x\n")
        result = survey.run(trees.root, trees.upstream)
        assert result.unmapped == []
        assert result.local_only == 1

    def test_declaration_overtaken_by_upstream_is_reported_stale(self, trees, monkeypatch):
        monkeypatch.setattr(config, "LOCAL_ONLY", ["pkgs/curl"])
        trees.pair("a\n", "b\n")
        result = survey.run(trees.root, trees.upstream)
        assert result.stale_local_only == ["pkgs/curl/default.nix"]
        # Still compared, so the divergence stays visible.
        assert "pkgs/curl.patch" in result.patches

    def test_undeclared_file_absent_upstream_is_still_missing(self, trees):
        trees.local("pkgs/only-here/default.nix", "x\n")
        result = survey.run(trees.root, trees.upstream)
        assert result.missing == ["pkgs/only-here/default.nix"]
        assert result.local_only == 0


class TestSymlinks:
    """A symlink is its target, not the bytes at the other end."""

    def _link(self, base, relative, target):
        path = base / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(target)

    def test_matching_targets_count_as_identical(self, trees):
        self._link(trees.root, "pkgs/curl/link.sh", "../../shared/link.sh")
        self._link(trees.upstream, "pkgs/by-name/cu/curl/link.sh", "../../shared/link.sh")
        result = survey.run(trees.root, trees.upstream)
        assert result.patches == {}
        assert result.opaque_differs == []

    def test_dangling_links_still_match_when_targets_agree(self, trees):
        # Neither link resolves; they are still the same link.
        self._link(trees.root, "pkgs/curl/link.sh", "../../../nowhere/link.sh")
        self._link(trees.upstream, "pkgs/by-name/cu/curl/link.sh", "../../../nowhere/link.sh")
        result = survey.run(trees.root, trees.upstream)
        assert result.missing == []
        assert result.patches == {}

    def test_differing_targets_become_a_note_not_a_diff(self, trees):
        self._link(trees.root, "pkgs/curl/link.sh", "../../a/link.sh")
        self._link(trees.upstream, "pkgs/by-name/cu/curl/link.sh", "../../b/link.sh")
        result = survey.run(trees.root, trees.upstream)
        assert result.opaque_differs == ["pkgs/curl/link.sh"]
        assert "@@" not in result.patches["pkgs/curl.patch"]

    def test_link_against_a_regular_file_is_missing(self, trees):
        self._link(trees.root, "pkgs/curl/link.sh", "../../a/link.sh")
        trees.remote("pkgs/by-name/cu/curl/link.sh", "real contents\n")
        result = survey.run(trees.root, trees.upstream)
        assert result.missing == ["pkgs/curl/link.sh"]


class TestIgnoredDivergence:
    def test_a_bump_is_held_back_from_patches(self, trees):
        trees.pair('{\n  version = "1.0";\n}\n',
            '{\n  version = "2.0";\n}\n',
        )
        result = survey.run(trees.root, trees.upstream)
        assert result.patches == {}
        assert list(result.ignored) == ["pkgs/curl.patch"]

    def test_a_bump_alongside_real_divergence_is_still_reviewed(self, trees):
        trees.pair('{\n  version = "1.0";\n  pname = "a";\n}\n',
            '{\n  version = "2.0";\n  pname = "b";\n}\n',
        )
        result = survey.run(trees.root, trees.upstream)
        assert "pkgs/curl.patch" in result.patches
        assert result.ignored == {}

    def test_bumps_are_written_to_their_own_report(self, trees):
        trees.pair('{\n  version = "1.0";\n}\n',
            '{\n  version = "2.0";\n}\n',
        )
        _generate(trees)
        report = _patches(trees) / config.REPORTS_DIR / "ignored-divergence.txt"
        body = report.read_text(encoding="utf-8")
        assert 'version = "1.0"' in body and 'version = "2.0"' in body
        assert not (_patches(trees) / "pkgs/curl.patch").exists()

    def test_a_held_back_bump_is_not_drift(self, trees):
        trees.pair('{\n  version = "1.0";\n}\n',
            '{\n  version = "2.0";\n}\n',
        )
        # --strict must stay quiet: a bump is news, not unaccepted divergence.
        assert _generate(trees, "--strict") == 0

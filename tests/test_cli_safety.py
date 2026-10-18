"""Filesystem regressions; only dedicated disposable fixture directories mutate.

Run: python3 -m unittest discover -s tests -v
Requires macOS and /bin/zsh. No installer or main dispatcher is executed. HOME
is inherited unchanged. Only OS integration (notifications, confirmation,
free-space queries, version lookup, open handles) and fixture catalogue discovery
are stubbed. Fixtures use a dedicated temporary directory directly under HOME,
outside synchronized Documents: FileProvider was observed changing metadata and
holding files open during copy verification. HOME itself is never reassigned;
cleanup removes only this test-created directory and its disposable contents.
DISCO_LIVRE_TEST_SOURCE may select the immutable audited source for RED evidence.
"""
import os
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ.get("DISCO_LIVRE_TEST_SOURCE", ROOT / "bin/disco-livre"))


@unittest.skipUnless(sys.platform == "darwin", "macOS filesystem semantics required")
class CLISafetyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix=".disco-livre-test-", dir=Path.home())
        self.addCleanup(self.temporary.cleanup)
        self.fixture = Path(self.temporary.name)
        self.config = self.fixture / "config"
        self.config.mkdir()
        source = SOURCE.read_text()
        self.assertIn("case ${1:-status} in", source)
        source = source.split("case ${1:-status} in")[0]
        source = source.replace('[[ -f $CONF ]] && source "$CONF"', "# isolated config")
        self.library = self.fixture / "library.zsh"
        self.library.write_text(source)

    def shell(self, body, *, analysis_mode="nao"):
        environment = dict(os.environ)
        environment.pop("DISCO_LIVRE_SIMULAR", None)
        environment.update(
            DISCO_LIVRE_DIR=str(self.config),
            TEST_LIBRARY=str(self.library),
            TEST_FIXTURE=str(self.fixture),
        )
        setup = '''
source "$TEST_LIBRARY"
LOG="$TEST_FIXTURE/config/log"
livre_kb() { print 1000000000; }
confirmar() { return 0; }
avisar() { return 0; }
ultima_versao() { return 0; }
# Tests of normal copies use the OS-boundary state "no open handles".
# A separate regression exercises rejection of an occupied directory.
lsof() { return 1; }
# Emulate Trash only inside fixtures; never send test files to the real Trash.
function /usr/bin/trash {
  local f
  mkdir -p "$TEST_FIXTURE/fake-trash"
  for f in "$@"; do
    [[ $f == -- ]] && continue
    [[ $f == $TEST_FIXTURE/* ]] || return 99
    command mv "$f" "$TEST_FIXTURE/fake-trash/${f:t}" || return
  done
}
osascript() {
  local f=${@[-1]}
  [[ $f == $TEST_FIXTURE/* && -e $f ]] && /usr/bin/trash "$f"
  return 0
}
'''
        if analysis_mode is not None:
            setup += f"\nSOMENTE_ANALISAR={analysis_mode}\n"
        return subprocess.run(
            ["/bin/zsh", "-f", "-c", setup + body],
            env=environment, text=True, capture_output=True, timeout=45,
        )

    def assert_shell_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def make_move(self):
        origin = self.fixture / "origin"
        destination = self.fixture / "destination"
        origin.mkdir()
        destination.mkdir()
        (origin / "data.txt").write_text("fixture payload\n")
        (origin / "link.txt").symlink_to("data.txt")
        subprocess.run(["/usr/bin/xattr", "-w", "com.discolivre.regression", "metadata",
                        str(origin / "data.txt")], check=True, capture_output=True)
        return origin, destination / "origin"

    def move(self):
        return self.shell('cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"\n')

    def test_move_preserves_relative_symbolic_links(self):
        _, final = self.make_move()
        self.assert_shell_ok(self.move())
        self.assertTrue((final / "link.txt").is_symlink(), "copy lost its internal symlink")
        self.assertEqual(os.readlink(final / "link.txt"), "data.txt")
        self.assertEqual((final / "link.txt").read_text(), "fixture payload\n")

    def test_move_preserves_extended_attributes(self):
        _, final = self.make_move()
        self.assert_shell_ok(self.move())
        result = subprocess.run(["/usr/bin/xattr", "-p", "com.discolivre.regression",
                                 str(final / "data.txt")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "metadata")

    def test_move_keeps_independent_recoverable_original(self):
        origin, final = self.make_move()
        self.assert_shell_ok(self.move())
        # Do not prescribe a backup filename: the original may be renamed, but
        # a second real directory must survive, independent of the external copy.
        backups = [p for p in self.fixture.rglob("data.txt")
                   if p.parent != final and not p.parent.is_symlink()
                   and p.read_text() == "fixture payload\n"]
        self.assertTrue(backups, "original was permanently removed after copying")

    def make_crashes(self):
        pending = self.fixture / "Crashpad" / "pending"
        pending.mkdir(parents=True)
        for index in range(501):
            (pending / f"{index}.dmp").write_text("diagnostic evidence")
        return pending

    def test_simulated_watcher_never_deletes_even_when_cleanup_enabled(self):
        pending = self.make_crashes()
        result = self.shell('''
DISCO_LIVRE_SIMULAR=1
AUTO_LIMPEZA=sim
LIMPAR_CRASH=sim
crashpads() { print -r -- "$TEST_FIXTURE/Crashpad"; }
cmd_vigiar
''')
        self.assert_shell_ok(result)
        self.assertEqual(len(list(pending.glob("*.dmp"))), 501)
        self.assertTrue(all(p.read_text() == "diagnostic evidence" for p in pending.glob("*.dmp")))

    def test_crash_cleanup_is_opt_in_by_default(self):
        result = self.shell('print -r -- "CRASH_DEFAULT=$LIMPAR_CRASH"\n')
        self.assert_shell_ok(result)
        self.assertIn("CRASH_DEFAULT=nao", result.stdout)

    def make_personal(self):
        personal = self.fixture / "personal"
        personal.mkdir()
        file = personal / "keep.cache"
        file.write_text("fixture, not cache")
        return file

    def counters(self, result):
        match = re.search(r"COUNTS=(\d+),(\d+)", result.stdout)
        self.assertIsNotNone(match, result.stdout + result.stderr)
        return tuple(map(int, match.groups()))

    def test_cache_outside_current_catalog_cannot_authorize_deletion(self):
        file = self.make_personal()
        result = self.shell('''
alvos() { return 0; }
id=$(id_de conteudo "$TEST_FIXTURE/personal")
limpar_linhas "$id|seguro|8192||Test item||conteudo|$TEST_FIXTURE/personal"
print -r -- "COUNTS=$LIMPOS,$LIBERADO_KB"
''')
        self.assertTrue(file.exists(), result.stdout + result.stderr)
        self.assertEqual(self.counters(result), (0, 0))

    def test_failed_delete_returns_failure_to_caller(self):
        self.make_personal()
        result = self.shell('''
alvos() { print -r -- "seguro|conteudo|Test item|$TEST_FIXTURE/personal|-|"; }
find() { return 13; }
apagar_alvo conteudo "$TEST_FIXTURE/personal"
''')
        self.assertNotEqual(result.returncode, 0, "deletion failure was swallowed")

    def test_failed_delete_does_not_count_items_or_space(self):
        file = self.make_personal()
        result = self.shell('''
alvos() { print -r -- "seguro|conteudo|Test item|$TEST_FIXTURE/personal|-|"; }
id=$(id_de conteudo "$TEST_FIXTURE/personal")
find() { return 13; }
limpar_linhas "$id|seguro|8192||Test item||conteudo|$TEST_FIXTURE/personal"
print -r -- "COUNTS=$LIMPOS,$LIBERADO_KB"
''')
        self.assertTrue(file.exists())
        self.assertEqual(self.counters(result), (0, 0), result.stdout + result.stderr)

    def test_stale_cached_size_is_not_reported_as_real_free_space(self):
        file = self.make_personal()
        result = self.shell('''
alvos() { print -r -- "seguro|conteudo|Test item|$TEST_FIXTURE/personal|-|"; }
id=$(id_de conteudo "$TEST_FIXTURE/personal")
limpar_linhas "$id|seguro|999999999||Test item||conteudo|$TEST_FIXTURE/personal"
print -r -- "COUNTS=$LIMPOS,$LIBERADO_KB"
''')
        self.assertFalse(file.exists(), result.stdout + result.stderr)
        count, released = self.counters(result)
        self.assertEqual(count, 1)
        # Free-space boundary is held constant in this test. Cached estimated
        # bytes must never become the reported physical-space increase.
        self.assertEqual(released, 0, "cached estimate presented as measured freed space")

    def test_simulated_move_does_not_change_original_or_destination(self):
        origin, final = self.make_move()
        result = self.shell('''
DISCO_LIVRE_SIMULAR=1
cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"
''')
        self.assert_shell_ok(result)
        self.assertFalse(origin.is_symlink())
        self.assertEqual((origin / "data.txt").read_text(), "fixture payload\n")
        self.assertFalse(final.exists())
        self.assertEqual(list(self.fixture.glob("origin*")), [origin])

    def test_simulated_empty_trash_never_calls_finder(self):
        result = self.shell('''
osascript() { print called >> "$TEST_FIXTURE/finder-called"; return 0; }
DISCO_LIVRE_SIMULAR=1
cmd_esvaziar_lixeira --sim
''')
        self.assert_shell_ok(result)
        self.assertFalse((self.fixture / "finder-called").exists())

    def test_watcher_with_auto_cleanup_off_preserves_crashes(self):
        pending = self.make_crashes()
        result = self.shell('''
AUTO_LIMPEZA=nao
LIMPAR_CRASH=sim
crashpads() { print -r -- "$TEST_FIXTURE/Crashpad"; }
cmd_vigiar
''')
        self.assert_shell_ok(result)
        self.assertEqual(len(list(pending.glob("*.dmp"))), 501)

    def test_symbolic_link_target_in_catalog_is_rejected(self):
        file = self.make_personal()
        (self.fixture / "alias").symlink_to("personal", target_is_directory=True)
        result = self.shell('''
alvos() { print -r -- "seguro|conteudo|Test item|$TEST_FIXTURE/alias|-|"; }
id=$(id_de conteudo "$TEST_FIXTURE/alias")
limpar_linhas "$id|seguro|8192||Test item||conteudo|$TEST_FIXTURE/alias"
print -r -- "COUNTS=$LIMPOS,$LIBERADO_KB"
''')
        self.assertTrue(file.exists(), result.stdout + result.stderr)
        self.assertEqual(self.counters(result), (0, 0))

    def test_symbolic_link_ancestor_in_catalog_is_rejected(self):
        file = self.make_personal()
        (self.fixture / "alias").symlink_to(".", target_is_directory=True)
        result = self.shell('''
alvos() { print -r -- "seguro|conteudo|Test item|$TEST_FIXTURE/alias/personal|-|"; }
id=$(id_de conteudo "$TEST_FIXTURE/alias/personal")
limpar_linhas "$id|seguro|8192||Test item||conteudo|$TEST_FIXTURE/alias/personal"
print -r -- "COUNTS=$LIMPOS,$LIBERADO_KB"
''')
        self.assertTrue(file.exists(), result.stdout + result.stderr)
        self.assertEqual(self.counters(result), (0, 0))

    def test_forged_id_cannot_authorize_catalog_target(self):
        file = self.make_personal()
        result = self.shell('''
alvos() { print -r -- "seguro|conteudo|Test item|$TEST_FIXTURE/personal|-|"; }
limpar_linhas "forged-id|seguro|8192||Test item||conteudo|$TEST_FIXTURE/personal"
print -r -- "COUNTS=$LIMPOS,$LIBERADO_KB"
''')
        self.assertTrue(file.exists(), result.stdout + result.stderr)
        self.assertEqual(self.counters(result), (0, 0))

    def test_forged_type_cannot_change_catalog_deletion_scope(self):
        file = self.make_personal()
        result = self.shell('''
alvos() { print -r -- "seguro|antigos|Test item|$TEST_FIXTURE/personal|-|"; }
id=$(id_de conteudo "$TEST_FIXTURE/personal")
limpar_linhas "$id|seguro|8192||Test item||conteudo|$TEST_FIXTURE/personal"
print -r -- "COUNTS=$LIMPOS,$LIBERADO_KB"
''')
        self.assertTrue(file.exists(), result.stdout + result.stderr)
        self.assertEqual(self.counters(result), (0, 0))

    def test_trash_failure_is_propagated(self):
        file = self.make_personal()
        result = self.shell('''
# Both supported OS boundaries fail without touching the actual user's Trash.
function /usr/bin/trash { return 13; }
osascript() { return 13; }
mandar_lixeira "$TEST_FIXTURE/personal"
''')
        self.assertNotEqual(result.returncode, 0, "trash command swallowed failure")
        self.assertTrue(file.exists())

    def test_incomplete_copy_fails_with_original_preserved(self):
        origin, _ = self.make_move()
        result = self.shell('''
# Simulate a copy tool that reports success but copies only one regular file.
ditto() { /bin/cp "$TEST_FIXTURE/origin/data.txt" "$TEST_FIXTURE/destination/origin/"; }
cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"
''')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(origin.is_symlink())
        self.assertEqual((origin / "data.txt").read_text(), "fixture payload\n")
        self.assertEqual(os.readlink(origin / "link.txt"), "data.txt")

    def test_move_rejects_corrupted_same_size_copy(self):
        origin, _ = self.make_move()
        result = self.shell('''
ditto() {
  command ditto "$@" || return
  print -rn -- 'corrupt payload!' > "$TEST_FIXTURE/destination/origin/data.txt"
}
cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"
''')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(origin.is_symlink())
        self.assertEqual((origin / "data.txt").read_text(), "fixture payload\n")

    def test_move_refuses_occupied_original(self):
        origin, final = self.make_move()
        result = self.shell('''
lsof() { print -r -- 'fixture-process 123 user 3r REG fixture'; return 0; }
cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"
''')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(origin.is_symlink())
        self.assertFalse(final.exists())
        self.assertEqual((origin / "data.txt").read_text(), "fixture payload\n")

    def test_move_refuses_permission_error_from_open_file_inspection(self):
        origin, final = self.make_move()
        result = self.shell('''
lsof() { print -r -- 'lsof: permission denied' >&2; return 2; }
cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"
''')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(origin.is_symlink())
        self.assertFalse(final.exists())
        self.assertEqual((origin / "data.txt").read_text(), "fixture payload\n")

    def test_move_refuses_warning_even_with_no_open_file_results(self):
        origin, final = self.make_move()
        result = self.shell('''
lsof() { print -r -- "lsof: WARNING: can't stat() filesystem" >&2; return 1; }
cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"
''')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(origin.is_symlink())
        self.assertFalse(final.exists())
        self.assertEqual((origin / "data.txt").read_text(), "fixture payload\n")

    def test_move_keeps_original_when_inspection_fails_after_copy(self):
        origin, final = self.make_move()
        result = self.shell('''
lsof() {
  if [[ ! -f $TEST_FIXTURE/inspected-once ]]; then
    print called > "$TEST_FIXTURE/inspected-once"
    return 1
  fi
  print -r -- 'lsof: permission denied' >&2
  return 2
}
cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"
''')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(origin.is_symlink())
        self.assertEqual((origin / "data.txt").read_text(), "fixture payload\n")
        self.assertEqual((final / "data.txt").read_text(), "fixture payload\n")

    def test_metadata_change_during_rename_restores_original_safely(self):
        origin, _ = self.make_move()
        result = self.shell('''
# Model the observed FileProvider race at the OS rename boundary: a new xattr
# appears on the renamed original after copying, before final verification.
mv() {
  command mv "$@" || return
  if [[ $2 == *disco-livre-backup* ]]; then
    xattr -w com.discolivre.external-change changed "$2/data.txt" || return
  fi
  return 0
}
cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"
''')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(origin.is_symlink())
        self.assertTrue(origin.is_dir())
        self.assertEqual((origin / "data.txt").read_text(), "fixture payload\n")
        attributes = subprocess.run(["/usr/bin/xattr", "-p", "com.discolivre.external-change",
                                     str(origin / "data.txt")], capture_output=True, text=True)
        self.assertEqual(attributes.returncode, 0, attributes.stderr)
        self.assertEqual(attributes.stdout.strip(), "changed")

    def test_move_preserves_metadata_across_ten_fixture_variations(self):
        for index in range(10):
            with self.subTest(variation=index):
                scenario = self.fixture / f"variation-{index}"
                scenario.mkdir()
                origin = scenario / "origin"
                origin.mkdir()
                destination = scenario / "destination"
                destination.mkdir()
                name = ["plain", "sp ace", "acentuação", "line\nbreak", "[glob]*"][index % 5]
                file = origin / name
                file.write_bytes(b"payload" * (index + 1))
                (origin / "relative").symlink_to(name)
                (origin / "empty directory").mkdir()
                subprocess.run(["/usr/bin/xattr", "-w", "com.discolivre.regression",
                                f"variation-{index}", str(file)], check=True, capture_output=True)
                result = self.shell(f'''
cmd_mover "$TEST_FIXTURE/variation-{index}/origin" "$TEST_FIXTURE/variation-{index}/destination"
''')
                if result.returncode:
                    evidence = {"variation": index, "stdout": result.stdout,
                                "stderr": result.stderr, "entries": []}
                    for entry in scenario.rglob("*"):
                        xattrs = subprocess.run(["/usr/bin/xattr", "-l", "-s", str(entry)],
                                                capture_output=True, text=True)
                        evidence["entries"].append({"path": str(entry.relative_to(scenario)),
                            "symlink": entry.is_symlink(), "xattrs": xattrs.stdout,
                            "xattr_errors": xattrs.stderr})
                    self.fail(json.dumps(evidence, ensure_ascii=False, indent=2))
                final = destination / "origin"
                self.assertEqual((final / name).read_bytes(), b"payload" * (index + 1))
                self.assertEqual(os.readlink(final / "relative"), name)

    def test_update_does_not_execute_downloaded_script(self):
        result = self.shell('''
ultima_versao() { print 9.9.9; }
curl() { print -r -- 'print reached > "$TEST_FIXTURE/update-sentinel"'; }
open() { return 0; }
cmd_atualizar
''')
        self.assertFalse((self.fixture / "update-sentinel").exists(),
                         "remote update payload executed: " + result.stdout + result.stderr)

    def test_bootstrap_does_not_download_mutable_main(self):
        tools = self.fixture / "tools"
        tools.mkdir()
        (self.fixture / "bootstrap-work").mkdir()
        stubs = {
            "curl": 'print -r -- "$*" > "$TEST_FIXTURE/download-called"; exit 13',
            "tar": 'exit 13',
            "mktemp": 'print -r -- "$TEST_FIXTURE/bootstrap-work"',
        }
        for name, body in stubs.items():
            executable = tools / name
            executable.write_text("#!/bin/zsh\n" + body + "\n")
            executable.chmod(0o755)
        result = subprocess.run(
            ["/bin/zsh", "-f", str(ROOT / "instalar.sh")],
            env={**os.environ, "TEST_FIXTURE": str(self.fixture),
                 "PATH": str(tools) + ":/usr/bin:/bin:/usr/sbin:/sbin"},
            text=True, capture_output=True, timeout=15,
        )
        marker = self.fixture / "download-called"
        downloaded = marker.read_text() if marker.exists() else ""
        self.assertNotRegex(downloaded, r"(?:/main(?:[/.]|$)|/heads/main(?:[/.]|$))",
                            result.stdout + result.stderr)

    def test_install_simulation_guard_precedes_installation_writes(self):
        # Deliberately static: running the vulnerable installer to demonstrate
        # this defect would install into the real HOME. The source must first
        # handle the simulation variable before its first installation mutation.
        source = (ROOT / "install.sh").read_text()
        executable_lines = "\n".join(line for line in source.splitlines()
                                     if not line.lstrip().startswith("#"))
        first_mutation = executable_lines.index('mkdir -p "$BIN"')
        self.assertIn("DISCO_LIVRE_SIMULAR", executable_lines[:first_mutation],
                      "installer writes into HOME before handling simulation")

    def test_legacy_config_migration_disables_implicit_cleanup(self):
        (self.config / "config").write_text(
            "META_GB=45\nAUTO_LIMPEZA=sim\nLIMPAR_CRASH=sim\n")
        # Source the fixture config for this migration test; unlike the common
        # isolated library, this preserves config initialization verbatim.
        self.library.write_text(SOURCE.read_text().split("case ${1:-status} in")[0])
        result = self.shell('print -r -- "MIGRATED=$META_GB,$AUTO_LIMPEZA,$LIMPAR_CRASH"\n')
        self.assert_shell_ok(result)
        self.assertIn("MIGRATED=45,nao,nao", result.stdout)

    def test_installer_staging_excludes_untracked_and_ignored_skill_payloads(self):
        repository = self.fixture / "repository"
        repository.mkdir()
        skill = repository / "skill" / "disco-livre"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("reviewed skill")
        (repository / ".gitignore").write_text("ignored-payload.sh\n")
        for arguments in [
            ["init", "-q"], ["add", "."],
            ["-c", "user.name=Regression", "-c", "user.email=fixture@example.invalid",
             "commit", "-qm", "fixture reviewed source"],
        ]:
            subprocess.run(["git", *arguments], cwd=repository, check=True, capture_output=True)
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip()
        (skill / "untracked-payload.sh").write_text("unreviewed code")
        (skill / "ignored-payload.sh").write_text("ignored unreviewed code")

        # Exercise only the installer's staging section. The installation body
        # never runs, so no CLI/skill/config/service can be written into HOME.
        source = (ROOT / "install.sh").read_text()
        self.assertIn('staging_source=', source, "installer has no isolated source staging")
        self.assertIn('cd "$staging_source"', source)
        staging = source[source.index("staging_source="):source.index('cd "$staging_source"')]
        staging += 'cd "$staging_source"\nfind . -type f -print\n'
        temporary = self.fixture / "archive-tmp"
        temporary.mkdir()
        result = subprocess.run(
            ["/bin/zsh", "-f", "-c", "set -e\n" + staging], cwd=repository,
            env={**os.environ, "REVISAO": revision, "TMPDIR": str(temporary)},
            text=True, capture_output=True, timeout=15,
        )
        self.assert_shell_ok(result)
        self.assertIn("./skill/disco-livre/SKILL.md", result.stdout.splitlines())
        self.assertNotIn("untracked-payload.sh", result.stdout)
        self.assertNotIn("ignored-payload.sh", result.stdout)

    def test_build_metadata_cleanup_preserves_quarantine_and_other_attributes(self):
        # Load only this pure filesystem helper, never the build script's main
        # body (which compiles, signs, and removes the real build directory).
        source = Path(os.environ.get("DISCO_LIVRE_TEST_BUILD_SOURCE", ROOT / "app" / "build.sh")).read_text()
        helper = re.search(r"(?ms)^limpar_metadados_build\(\)\s*\{.*?^\}", source)
        self.assertIsNotNone(helper, "build has no selective bundle metadata cleanup helper")
        bundle = self.fixture / "Generated.app"
        executable = bundle / "Contents" / "MacOS" / "fixture"
        executable.parent.mkdir(parents=True)
        executable.write_bytes(b"generated fixture executable")
        for entry in [bundle, executable]:
            for attribute, value in [
                ("com.apple.quarantine", "0081;00000000;DiscoLivreRegression;"),
                ("com.discolivre.regression", "preserve custom metadata"),
            ]:
                subprocess.run(["/usr/bin/xattr", "-w", attribute, value, str(entry)],
                               check=True, capture_output=True)
            subprocess.run(["/usr/bin/xattr", "-wx", "com.apple.FinderInfo",
                            "54455854" + "00" * 28, str(entry)], check=True, capture_output=True)
        subprocess.run(["/usr/bin/xattr", "-w", "com.apple.ResourceFork", "fixture resource",
                        str(executable)], check=True, capture_output=True)

        helper_file = self.fixture / "build-helper.zsh"
        helper_file.write_text(helper.group(0) + '\nlimpar_metadados_build "$1"\n')
        result = subprocess.run(["/bin/zsh", "-f", str(helper_file), str(bundle)],
                                text=True, capture_output=True, timeout=15)
        self.assert_shell_ok(result)
        for entry in [bundle, executable]:
            attributes = subprocess.check_output(["/usr/bin/xattr", str(entry)], text=True).splitlines()
            self.assertNotIn("com.apple.FinderInfo", attributes)
            self.assertNotIn("com.apple.ResourceFork", attributes)
            quarantine = subprocess.check_output(["/usr/bin/xattr", "-p", "com.apple.quarantine",
                                                  str(entry)], text=True).strip()
            custom = subprocess.check_output(["/usr/bin/xattr", "-p", "com.discolivre.regression",
                                              str(entry)], text=True).strip()
            self.assertEqual(quarantine, "0081;00000000;DiscoLivreRegression;")
            self.assertEqual(custom, "preserve custom metadata")
        self.assertEqual(executable.read_bytes(), b"generated fixture executable")


if __name__ == "__main__":
    unittest.main()

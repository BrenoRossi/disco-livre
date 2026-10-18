"""Analysis-only defaults and recoverable cleanup; never touches the real Trash."""
import json
import os
import re
import subprocess
import unittest

import test_cli_safety as legacy


class AnalysisModeTests(unittest.TestCase):
    # Reuse fixture/OS-boundary harness without inheriting its test methods.
    setUp = legacy.CLISafetyTests.setUp
    assert_shell_ok = legacy.CLISafetyTests.assert_shell_ok
    make_move = legacy.CLISafetyTests.make_move
    make_crashes = legacy.CLISafetyTests.make_crashes

    def shell(self, body):
        return legacy.CLISafetyTests.shell(self, body, analysis_mode=None)

    def cache(self):
        directory = self.fixture / "cache"
        directory.mkdir()
        (directory / "payload.cache").write_text("regenerable cached bytes")
        return directory

    def mutation_boundaries(self):
        return '''
function /usr/bin/trash { print trash >> "$TEST_FIXTURE/mutation"; return 0; }
osascript() { print finder >> "$TEST_FIXTURE/mutation"; return 0; }
find() {
  if [[ " $* " == *' -delete '* ]]; then
    print delete >> "$TEST_FIXTURE/mutation"; return 0
  fi
  command find "$@"
}
ditto() { print copy >> "$TEST_FIXTURE/mutation"; return 13; }
'''

    def test_analysis_only_is_default(self):
        result = self.shell('print -r -- "MODE=$SOMENTE_ANALISAR"\n')
        self.assert_shell_ok(result)
        self.assertIn("MODE=sim", result.stdout)

    def test_default_blocks_low_level_delete(self):
        cache = self.cache()
        result = self.shell(self.mutation_boundaries() + '''
alvos() { print -r -- "seguro|conteudo|Cache|$TEST_FIXTURE/cache|-|"; }
apagar_alvo conteudo "$TEST_FIXTURE/cache"
''')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)
        self.assertTrue((cache / "payload.cache").exists())

    def test_default_blocks_direct_trash(self):
        cache = self.cache()
        result = self.shell(self.mutation_boundaries() + 'mandar_lixeira "$TEST_FIXTURE/cache/payload.cache"\n')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)
        self.assertTrue((cache / "payload.cache").exists())

    def test_default_blocks_move(self):
        origin, final = self.make_move()
        result = self.shell(self.mutation_boundaries() + 'cmd_mover "$TEST_FIXTURE/origin" "$TEST_FIXTURE/destination"\n')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)
        self.assertFalse(origin.is_symlink())
        self.assertFalse(final.exists())

    def test_default_blocks_empty_trash_even_with_yes_argument(self):
        result = self.shell(self.mutation_boundaries() + 'cmd_esvaziar_lixeira --sim\n')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)

    def test_edit_mode_still_requires_permanent_deletion_confirmation(self):
        result = self.shell(self.mutation_boundaries() + '''
SOMENTE_ANALISAR=nao
cmd_esvaziar_lixeira --sim
''')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)

    def test_default_also_blocks_explicit_permanent_deletion_flag(self):
        result = self.shell(self.mutation_boundaries() + '''
cmd_esvaziar_lixeira --confirmar-exclusao-permanente
''')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)

    def test_watcher_only_warns_with_analysis_mode_and_both_cleanup_flags(self):
        pending = self.make_crashes()
        result = self.shell(self.mutation_boundaries() + '''
AUTO_LIMPEZA=sim
LIMPAR_CRASH=sim
avisar() { print -r -- "$*" >> "$TEST_FIXTURE/notifications"; }
crashpads() { print -r -- "$TEST_FIXTURE/Crashpad"; }
alvos() { print -r -- "seguro|conteudo|Crashes|$TEST_FIXTURE/Crashpad/pending|-|"; }
cmd_vigiar
''')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)
        self.assertEqual(len(list(pending.glob("*.dmp"))), 501)
        self.assertTrue((self.fixture / "notifications").exists(), result.stdout + result.stderr)

    def test_opted_in_cleanup_uses_fixture_trash_and_not_permanent_delete(self):
        cache = self.cache()
        result = self.shell('''
SOMENTE_ANALISAR=nao
alvos() { print -r -- "seguro|conteudo|Cache|$TEST_FIXTURE/cache|-|"; }
find() {
  if [[ " $* " == *' -delete '* ]]; then
    print delete >> "$TEST_FIXTURE/permanent-delete"; return 0
  fi
  command find "$@"
}
apagar_alvo conteudo "$TEST_FIXTURE/cache"
''')
        self.assert_shell_ok(result)
        self.assertFalse((self.fixture / "permanent-delete").exists(), result.stdout + result.stderr)
        self.assertFalse((cache / "payload.cache").exists(), "cleanup did not reach the fixture Trash")
        self.assertEqual((self.fixture / "fake-trash" / "payload.cache").read_text(), "regenerable cached bytes")

    def test_protected_virtual_machine_document_and_backup_inside_cache_survive(self):
        for index, name in enumerate(["Windows.pvm", "report.docx", "archive.backupdb", "notes.txt"]):
            with self.subTest(protected=name):
                cache = self.fixture / f"cache-{index}"
                cache.mkdir()
                protected = cache / name
                if name.endswith((".pvm", ".backupdb")):
                    protected.mkdir()
                    protected = protected / "data"
                protected.write_text("personal evidence")
                result = self.shell(self.mutation_boundaries() + f'''
SOMENTE_ANALISAR=nao
alvos() {{ print -r -- "seguro|conteudo|Cache|$TEST_FIXTURE/cache-{index}|-|"; }}
apagar_alvo conteudo "$TEST_FIXTURE/cache-{index}"
''')
                marker = self.fixture / "mutation"
                mutated = marker.read_text() if marker.exists() else ""
                marker.unlink(missing_ok=True)
                self.assertEqual(mutated, "", result.stdout + result.stderr)
                self.assertEqual(protected.read_text(), "personal evidence")

    def test_direct_trash_refuses_personal_document_in_edit_mode(self):
        document = self.fixture / "report.docx"
        document.write_text("personal document")
        result = self.shell(self.mutation_boundaries() + '''
SOMENTE_ANALISAR=nao
mandar_lixeira "$TEST_FIXTURE/report.docx"
''')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)
        self.assertEqual(document.read_text(), "personal document")

    def test_cleanup_refuses_cache_nested_in_virtual_machine(self):
        cache = self.fixture / "Windows.pvm" / "cache"
        cache.mkdir(parents=True)
        (cache / "data.cache").write_text("virtual machine data")
        result = self.shell(self.mutation_boundaries() + '''
SOMENTE_ANALISAR=nao
alvos() { print -r -- "seguro|conteudo|Cache|$TEST_FIXTURE/Windows.pvm/cache|-|"; }
apagar_alvo conteudo "$TEST_FIXTURE/Windows.pvm/cache"
''')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)
        self.assertEqual((cache / "data.cache").read_text(), "virtual machine data")

    def test_invalid_analysis_configuration_fails_closed(self):
        (self.config / "config").write_text(
            "SOMENTE_ANALISAR=talvez\nAUTO_LIMPEZA=sim\nLIMPAR_CRASH=sim\nSEGURANCA_VERSAO=2\n")
        self.library.write_text(legacy.SOURCE.read_text().split("case ${1:-status} in")[0])
        self.cache()
        result = self.shell(self.mutation_boundaries() + '''
print -r -- "MODE=$SOMENTE_ANALISAR"
alvos() { print -r -- "seguro|conteudo|Cache|$TEST_FIXTURE/cache|-|"; }
apagar_alvo conteudo "$TEST_FIXTURE/cache"
''')
        self.assertFalse((self.fixture / "mutation").exists(), result.stdout + result.stderr)
        self.assertTrue(result.returncode != 0 or "MODE=sim" in result.stdout,
                        "invalid config enabled writes: " + result.stdout + result.stderr)

    def test_configuration_is_data_and_never_executes_shell_payload(self):
        (self.config / "config").write_text(
            'SOMENTE_ANALISAR=$(print executed > "$TEST_FIXTURE/config-code")\n')
        self.library.write_text(legacy.SOURCE.read_text().split("case ${1:-status} in")[0])
        result = self.shell('print -r -- "MODE=$SOMENTE_ANALISAR"\n')
        self.assertFalse((self.fixture / "config-code").exists(), result.stdout + result.stderr)

    def test_new_candidate_after_analysis_is_not_implicitly_selected(self):
        initial = self.fixture / "cache-initial"
        later = self.fixture / "cache-later"
        initial.mkdir()
        later.mkdir()
        (initial / "initial.cache").write_bytes(b"a" * (6 * 1024 * 1024))
        (later / "later.cache").write_bytes(b"b" * (6 * 1024 * 1024))
        result = self.shell('''
SOMENTE_ANALISAR=nao
alvos() {
  print -r -- "seguro|conteudo|Initial cache|$TEST_FIXTURE/cache-initial|-|"
  if [[ -f $TEST_FIXTURE/candidate-added ]]; then
    print -r -- "seguro|conteudo|Later cache|$TEST_FIXTURE/cache-later|-|"
  fi
}
analysis=$(linhas_geral --nova)
selected=${analysis%%|*}
[[ -n $selected ]] || exit 99
print new > "$TEST_FIXTURE/candidate-added"
cmd_limpar_itens "$selected" --json
''')
        self.assert_shell_ok(result)
        outcome = json.loads(result.stdout)
        self.assertEqual(outcome["itens"], 1)
        self.assertEqual(outcome["erros"], [])
        self.assertFalse((initial / "initial.cache").exists())
        self.assertEqual((self.fixture / "fake-trash" / "initial.cache").stat().st_size, 6 * 1024 * 1024)
        self.assertEqual((later / "later.cache").stat().st_size, 6 * 1024 * 1024)

    def test_swift_summary_cleanup_opens_current_analysis(self):
        source = (legacy.ROOT / "app" / "DiscoLivre.swift").read_text()
        method = re.search(r"(?ms)^    func limpar\(\) async \{(.*?)^    \}", source)
        self.assertIsNotNone(method)
        self.assertIn("await analisarGeral()", method.group(1))
        self.assertNotIn("CLI.executar", method.group(1), "summary must not execute global cleanup")
        self.assertNotIn('"limpar"', method.group(1), "summary must first select current IDs")

    def notarization_fixture(self):
        root = self.fixture / "notarization-source"
        scripts = root / "scripts"
        app = root / "app"
        tools = self.fixture / "notarization-tools"
        scripts.mkdir(parents=True)
        app.mkdir()
        tools.mkdir()
        script = scripts / "notarizar.sh"
        script.write_bytes((legacy.ROOT / "scripts" / "notarizar.sh").read_bytes())
        build = app / "build.sh"
        build.write_text('#!/bin/zsh\nprint build >> "$TEST_FIXTURE/build-called"\nexit 97\n')
        build.chmod(0o755)
        for tool in ["security", "xcrun", "codesign", "spctl"]:
            fake = tools / tool
            fake.write_text(f'#!/bin/zsh\nprint called >> "$TEST_FIXTURE/{tool}-called"\nexit 0\n')
            fake.chmod(0o755)
        environment = dict(os.environ)
        environment.pop("DISCO_LIVRE_SIMULAR", None)
        environment.update(TEST_FIXTURE=str(self.fixture),
                           PATH=str(tools) + ":/usr/bin:/bin:/usr/sbin:/sbin")
        return script, environment

    def test_notarization_simulation_never_queries_keys_builds_or_submits(self):
        script, environment = self.notarization_fixture()
        environment["DISCO_LIVRE_SIMULAR"] = "1"
        result = subprocess.run(["/bin/zsh", "-f", str(script)], env=environment,
                                capture_output=True, text=True, timeout=15)
        self.assert_shell_ok(result)
        for boundary in ["security", "build", "codesign", "xcrun", "spctl"]:
            self.assertFalse((self.fixture / f"{boundary}-called").exists())

    def test_notarization_without_identity_fails_before_build_or_submit(self):
        script, environment = self.notarization_fixture()
        result = subprocess.run(["/bin/zsh", "-f", str(script),
                                 "Developer ID Application: Regression Fixture (TEST)", "fixture-profile"],
                                env=environment, capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.fixture / "security-called").exists())
        for boundary in ["build", "codesign", "xcrun", "spctl"]:
            self.assertFalse((self.fixture / f"{boundary}-called").exists())


if __name__ == "__main__":
    unittest.main()

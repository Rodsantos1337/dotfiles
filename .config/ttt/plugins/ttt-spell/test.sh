#!/usr/bin/env bash
# Functional tests for the spell plugin.
#
# Each case drives the real ttt binary through a scripted --exec session with
# the plugin installed under its manifest's actual permissions (not --plugin's
# grant-everything mode), so permission scoping is covered too.
#
#   ./test.sh                      # uses ../../bin/ttt
#   TTT_BIN=/path/to/ttt ./test.sh
#
# Requires: ttt, aspell with an English dictionary, python3.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer an explicit TTT_BIN, then a checkout this plugin sits inside, then PATH.
if [ -z "${TTT_BIN:-}" ]; then
  if [ -x "$here/../../bin/ttt" ]; then
    TTT_BIN="$here/../../bin/ttt"
  else
    TTT_BIN="$(command -v ttt || true)"
  fi
fi

if [ -z "$TTT_BIN" ] || [ ! -x "$TTT_BIN" ]; then
  echo "ttt binary not found; set TTT_BIN=/path/to/ttt" >&2
  exit 1
fi
if ! command -v aspell >/dev/null 2>&1; then
  echo "SKIP: aspell is not installed" >&2
  exit 0
fi
if ! aspell dump dicts 2>/dev/null | grep -q .; then
  echo "SKIP: aspell has no dictionary installed" >&2
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# aspell writes the personal dictionary under $HOME; keep the real one clean.
export HOME="$work/home"
mkdir -p "$HOME"

pass=0
fail=0

# run <name> <file> <exec-script> [settings-json]
# Leaves the debug dump in $work/state.json and the screen in $work/screen.txt.
run() {
  local file="$2" script="$3" settings="${4:-}"
  local cfg="$work/cfg"
  rm -rf "$cfg"
  mkdir -p "$cfg/plugins"
  cp -r "$here" "$cfg/plugins/spell"
  [ -n "$settings" ] && printf '%s\n' "$settings" >"$cfg/settings.json"

  # The registry must repeat the manifest's permissions verbatim, or ttt
  # treats them as changed and puts up the approval dialog instead of loading.
  python3 - "$cfg" <<'PY'
import json, sys, pathlib
cfg = pathlib.Path(sys.argv[1])
m = json.loads((cfg / "plugins" / "spell" / "plugin.ttt.json").read_text())
(cfg / "plugins.ttt.json").write_text(json.dumps([{
    "name": m["name"],
    "displayName": m.get("displayName", ""),
    "version": m.get("version", ""),
    "enabled": True,
    "permissions": m["permissions"],
}]))
PY

  rm -f "$work/state.json" "$work/screen.txt"
  # Run from the config dir so the repo's own plugins/ is not also scanned.
  (cd "$cfg" && TTT_CONFIG_DIR="$cfg" timeout 60 "$TTT_BIN" --size 110x30 "$file" \
    --exec "$script; screenshot $work/screen.txt; debug $work/state.json; quit") >/dev/null 2>&1
}

check() { # check <name> <python-expression-returning-bool>
  local name="$1" expr="$2"
  local out
  out="$(python3 - "$work" "$expr" <<'PY'
import json, sys, pathlib
work, expr = pathlib.Path(sys.argv[1]), sys.argv[2]
state = json.loads((work / "state.json").read_text()) if (work / "state.json").exists() else {}
screen = (work / "screen.txt").read_text() if (work / "screen.txt").exists() else ""
diags = state.get("diagnostics") or []
spell = [d for d in diags if d.get("source") == "spell"]
text = (state.get("buffer") or {}).get("text") or []
words = [(d["start_line"], d["start_col"], d["end_col"]) for d in spell]
print("PASS" if eval(expr) else "FAIL: " + repr({
    "spell_diags": spell, "buffer": text, "screen_tail": screen[-400:],
})[:700])
PY
)"
  if [ "${out:0:4}" = "PASS" ]; then
    pass=$((pass + 1)); echo "  ok   $name"
  else
    fail=$((fail + 1)); echo "  FAIL $name"; echo "       ${out}"
  fi
}

echo "spell plugin tests"

# --- flags misspellings in markdown, respecting filter modes -----------------
printf '# My Documnet\n\nA smiple test, a `codespan`, and https://example.com/teh here.\n' >"$work/doc.md"
run "markdown" "$work/doc.md" 'wait 1800'
# "Documnet" at line 1 col 6..13 and "smiple" at line 3 col 3..9 (1-based),
# reported 0-based. Neither the code span nor the URL may be flagged.
check "flags misspelled words" "words == [(0, 5, 13), (2, 2, 8)]"
check "skips code spans and URLs" "not any('codespan' in d['message'] or 'teh' in d['message'] for d in spell)"
check "suggests a correction" "any('simple' in d['message'] for d in spell)"

# --- rune columns, not byte offsets ------------------------------------------
# "naïve" is 5 runes / 6 bytes, so a byte-based offset would put tesst at 9.
printf 'a na\xc3\xafve tesst here\n' >"$work/mb.md"
run "multibyte" "$work/mb.md" 'wait 1800'
check "reports rune columns" "words == [(0, 2, 7), (0, 8, 13)]"

# --- code files are not checked ----------------------------------------------
printf 'package main\n\n// a smiple typo\nfunc main() {}\n' >"$work/code.go"
run "code" "$work/code.go" 'wait 1800'
check "skips code files" "spell == []"

# --- lexer-less files are matched by name, not blanket-accepted --------------
printf 'a smiple commit mesage\n' >"$work/COMMIT_EDITMSG"
run "commit-msg" "$work/COMMIT_EDITMSG" 'wait 1800'
check "checks COMMIT_EDITMSG" "len(spell) == 2"

# A .log has no lexer either, but checking it is pure noise.
printf 'a smiple log line with teh typo\n' >"$work/app.log"
run "log" "$work/app.log" 'wait 1800'
check "skips .log files" "spell == []"

printf -- '-----BEGIN CERTIFICATE-----\nMIIBkTCB+wIJAKZq smiple Zm9vYmFy\n' >"$work/key.pem"
run "pem" "$work/key.pem" 'wait 1800'
check "skips .pem files" "spell == []"

# --- filetype overrides -------------------------------------------------------
run "filetypes-off" "$work/doc.md" 'wait 1800' '{"spell":{"filetypes":{"markdown":false}}}'
check "spell.filetypes can disable a language" "spell == []"

run "filenames" "$work/app.log" 'wait 1800' '{"spell":{"filenames":["app.log"]}}'
check "spell.filenames can opt a file in" "len(spell) >= 1"

printf 'a smiple asciidoc line\n' >"$work/notes.adoc"
run "glob" "$work/notes.adoc" 'wait 1800' '{"spell":{"filenames":["*.adoc"]}}'
check "spell.filenames accepts globs" "len(spell) >= 1"

# The same glob must not drag in other extensionless-language files.
run "glob-scoped" "$work/app.log" 'wait 1800' '{"spell":{"filenames":["*.adoc"]}}'
check "globs stay scoped" "spell == []"

# --- correcting a word --------------------------------------------------------
printf 'a smiple test\n' >"$work/fix.md"
run "correct" "$work/fix.md" \
  'wait 1800; click 10 4; wait 200; exec "Spell Check: Correct Word at Cursor"; wait 500; key enter; wait 1500'
check "applies the correction" "text[0] == 'a simple test'"
check "clears the diagnostic" "spell == []"

run "undo" "$work/fix.md" \
  'wait 1800; click 10 4; wait 200; exec "Spell Check: Correct Word at Cursor"; wait 500; key enter; wait 1200; exec "Undo"; wait 300'
check "correction is undoable" "text[0] == 'a smiple test'"

# --- a stale span must never rewrite the wrong text --------------------------
# A long debounce keeps the re-check from firing, so the span goes stale when
# the line is edited underneath it.
run "stale" "$work/fix.md" \
  'wait 1500; exec "Spell Check: Check Now"; wait 1200; click 6 4; key home; type XX; wait 400; click 8 4; exec "Spell Check: Correct Word at Cursor"; wait 400; key enter; wait 600' \
  '{"spell":{"debounce":60000}}'
check "refuses a stale correction" "text[0] == 'XXa smiple test'"
check "explains the refusal" "'text changed' in screen"

# --- toggling off ------------------------------------------------------------
run "toggle" "$work/doc.md" 'wait 1800; exec "Spell Check: Toggle"; wait 800'
check "toggle clears diagnostics" "spell == []"

run "disabled" "$work/doc.md" 'wait 1800' '{"spell":{"enabled":false}}'
check "honours spell.enabled=false" "spell == []"

# --- personal dictionary ------------------------------------------------------
printf 'the zzqqwxyz word\n' >"$work/dict.md"
run "dictionary" "$work/dict.md" \
  'wait 1800; click 12 4; wait 200; exec "Spell Check: Add Word at Cursor to Dictionary"; wait 2000'
check "added word is accepted" "spell == []"
check "personal dictionary written" "'zzqqwxyz' in open(__import__('os').environ['HOME'] + '/.aspell.en.pws').read()"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]

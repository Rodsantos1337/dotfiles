# spell

Spell checking for prose files in [ttt](https://github.com/eugenioenko/ttt),
backed by [aspell](http://aspell.net).

Misspelled words get a curly underline and appear in the Diagnostics panel.
Corrections are available from the right-click menu or from the command
palette, and words can be added to your personal aspell dictionary.

Only prose is checked. Source files are left alone, and within Markdown the
aspell filter keeps code spans and URLs out of the results.

## What gets checked

Files are matched on the language ttt detects, not on the extension:

| Language | aspell filter |
|---|---|
| `markdown` | `markdown` — skips code spans, links and URLs |
| `HTML` | `html` — skips tags and attributes |
| `XML` | `sgml` |
| `TeX` | `tex` — skips macros |
| `plaintext`, `reStructuredText`, `Org Mode` | default — skips URLs |

Files no language matches are checked only when their name is in a short
allowlist: `COMMIT_EDITMSG`, `MERGE_MSG`, `TAG_EDITMSG`, `NOTES_EDITMSG`,
`README`, `CHANGELOG`, `CONTRIBUTING`, `TODO`, `AUTHORS`.

That allowlist is deliberate. Checking every file without a known language
would drag in `.log`, `.lock`, `.pem` and similar, where the result is hundreds
of meaningless warnings and a full aspell run on every keystroke.

Both lists are configurable — see `spell.filetypes` and `spell.filenames`
below.

## Requirements

> **aspell is not bundled and is not installed for you.** The plugin needs both
> the `aspell` binary and a dictionary for your language on your `PATH`. Without
> them the plugin loads but stays inert, reporting the problem once in the
> status bar rather than on every keystroke.

You must install both packages yourself — a dictionary is a separate package
from the binary, and aspell is useless without one:

| Platform | Command |
|---|---|
| Debian / Ubuntu | `sudo apt install aspell aspell-en` |
| Fedora | `sudo dnf install aspell aspell-en` |
| Arch | `sudo pacman -S aspell aspell-en` |
| Alpine | `sudo apk add aspell aspell-en` |
| macOS (Homebrew) | `brew install aspell` (dictionaries included) |

Substitute your own language for `aspell-en`. Verify the install with:

```sh
aspell dump dicts     # must list at least one dictionary
```

Because the plugin runs an external binary, its manifest declares
`"system.exec": ["aspell"]`, and ttt will ask you to approve that on first
load. The allowlist is exactly one entry: the plugin cannot execute anything
other than `aspell`.

## Install

Clone into your ttt plugins directory:

```sh
git clone https://github.com/eugenioenko/ttt-spell \
  ~/.config/ttt/plugins/spell
```

Restart ttt, or run **Plugins: Reload** from the command palette, and approve
the permission prompt.

## Usage

Checking runs automatically as you type (debounced), when a file is opened, and
when you switch tabs.

**Right-click a misspelled word** for up to three corrections plus *Add to
dictionary*. For the full list of suggestions, use `Spell Check: Correct Word
at Cursor` below, which lets you type any spelling you like.

Command palette:

| Command | Description |
|---|---|
| `Spell Check: Correct Word at Cursor` | Opens the command line prefilled with the best suggestion, with the runners-up listed alongside. Press Enter to accept, or edit it first. |
| `Spell Check: Add Word at Cursor to Dictionary` | Adds the word to your personal aspell dictionary (`~/.aspell.<lang>.pws`). |
| `Spell Check: Toggle` | Turns checking on or off and remembers the choice. |
| `Spell Check: Check Now` | Re-checks immediately, ignoring the debounce. |

## Settings

Configured in `~/.config/ttt/settings.json`. All are optional and are read
live — changes apply without reloading the plugin.

```json
{
  "spell": {
    "enabled": true,
    "lang": "en_US",
    "debounce": 500,
    "filetypes": {
      "HTML": false
    },
    "filenames": ["COMMIT_EDITMSG", "*.adoc"]
  }
}
```

| Key | Default | Description |
|---|---|---|
| `spell.enabled` | `true` | Whether checking is active. Toggling from the command palette writes this. |
| `spell.lang` | *(unset)* | aspell dictionary code, e.g. `en_US` or `de_DE`. When unset aspell follows your locale. |
| `spell.debounce` | `500` | Milliseconds of idle time after a change before re-checking. Minimum 50. |
| `spell.filetypes` | *(unset)* | Per-language overrides, keyed by the language name ttt reports. A string sets the aspell filter mode (`""` for the default filter); `false` turns a language off. Merges with the built-in table rather than replacing it. |
| `spell.filenames` | *(unset)* | Replaces the built-in allowlist for files with no detected language. Entries are exact base names or globs such as `*.adoc`. |

To find the name to use as a `spell.filetypes` key, open a file of that type
and read the language shown at the right-hand end of the status bar.

Stop checking HTML, leaving every other language alone:

```json
{ "spell": { "filetypes": { "HTML": false } } }
```

Check AsciiDoc files. ttt reports no language for `.adoc`, so this belongs in
`filenames` as a glob rather than in `filetypes`. Note that setting
`filenames` *replaces* the built-in list, so repeat any entries you still
want:

```json
{ "spell": { "filenames": ["COMMIT_EDITMSG", "README", "*.adoc"] } }
```

## How it works

The buffer is written to aspell's stdin using its ispell-compatible pipe
protocol: terse mode, then one `^`-prefixed data line per buffer line. The `^`
prefix matters — without it a line starting with `*` or `#` would be read as a
protocol command rather than as text.

aspell answers with one result block per input line, terminated by a blank
line, so blank lines are what advance the line counter while parsing. The
offsets it reports are 1-based **rune** columns relative to the original line,
which is exactly what ttt's diagnostics API expects, so they are used directly.
That is what keeps squiggles aligned on lines containing multi-byte characters.

Checks run through `sys.exec_async`, so a large file never blocks the UI, and a
generation counter discards replies from superseded runs.

Applying a correction re-verifies the word is still where the check said it was
before replacing it. Spans can go stale between a check and the moment you act
on one, and without that guard an edit elsewhere on the line would shift the
range and the replacement would corrupt unrelated text. When the check is
stale, the plugin says so and re-checks instead.

## Permissions

| Permission | Why |
|---|---|
| `system.exec: ["aspell"]` | Run aspell. Limited to that one binary. |
| `editor.read` | Read buffer lines to check, and register the context menu. |
| `editor.write` | Apply corrections. |
| `editor.diagnostics` | Draw the squiggles. |
| `events.editor`, `events.file` | Re-check on change, tab switch and file open. |
| `commands` | Register the command palette entries. |
| `keybindings` | Use the command line for the correction prompt. |
| `settings`, `settings_keys: ["spell.*"]` | Read and persist the settings above. Scoped so it cannot touch any other setting. |

## Tests

```sh
./test.sh                       # expects ../../bin/ttt
TTT_BIN=/path/to/ttt ./test.sh
```

The suite drives the real ttt binary through scripted sessions with the plugin
installed under its manifest's actual permissions, so permission scoping is
exercised alongside behaviour. It skips cleanly when aspell or a dictionary is
missing, and it sandboxes `HOME` so it never writes to your real personal
dictionary.

## Limitations

- The whole file is re-checked on each run rather than incrementally. That is
  fine at prose sizes; very large files will feel the debounce.
- A spell underline and an LSP diagnostic on the same cell cannot stack.
- Suggestions come from the last completed check, so a word typed within the
  debounce window may not offer corrections yet.

## License

MIT

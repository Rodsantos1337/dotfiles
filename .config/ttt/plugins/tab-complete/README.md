# tab-complete — fork tweak

Cursor-style inline completion for ttt: after a typing pause the editor asks a
local OpenAI-compatible model for a fill-in-the-middle completion and draws it
as ghost text at the cursor. **Tab** accepts it as one undo step, **Esc**
dismisses it, and typing anything drops it.

This directory is a fork-local plugin. It is not upstream code, so an import
from `eugenioenko/ttt` never conflicts with it — but it depends on one small
core change, recorded as `tweaks/0008-feat-editor-inline-suggestions.patch`.
If that patch fails to apply after an upstream import, this file tells you
what to redo and how to prove it works again.

## Install

Copy the directory (keep the name: it must match the manifest's `name`) into
the plugin folder, then allow it in the approval dialog:

```sh
cp -r tweaks/tab-complete ~/.config/ttt/plugins/tab-complete
```

For development without approval, load the single file:

```sh
bin/ttt --plugin tweaks/tab-complete/init.lua file.go
```

`--plugin` grants every permission except `system.exec`, which is why the
network call works there. A `plugin.ttt.json` next to the file would narrow
the permissions to the ones listed in it.

## Configure

Defaults target LM Studio on its default port. Config is stored in the
plugin's own `ttt.storage` (settings.json only persists keys that already
exist in ttt's schema):

| Storage key | Default |
|---|---|
| `endpoint` | `http://127.0.0.1:1234/v1/completions` |
| `model` | `qwen2.5-coder-3b` |
| `template` | `qwen` (`qwen`, `starcoder`, `codellama`, `codestral`, `glm`) |
| `max_tokens` | `96` |
| `debounce` | `250` (ms) |
| `context` | `4000` (chars per side) |
| `extensions` | comma list of file extensions |
| `enabled` | `true` |
| `api_key` | unset (adds `Authorization: Bearer …`) |

Change them with **Tab Complete: Configure** (command palette).
**Tab Complete: Request Now** is on `ctrl+k a`; the request returns here so it
always quotes the live cursor.

LM Studio: load `qwen2.5-coder-3b`, then enable the local server (*Developer*
tab, default `http://127.0.0.1:1234`). Ollama works too with
`http://127.0.0.1:11434/v1/completions` and `qwen2.5-coder:3b`.

## Core change this plugin depends on

One new presentation feature: **inline (ghost) text**. Before it, plugin
decorations could only tint lines, highlight ranges, or draw notes on rows
*under* a line; nothing could draw after the cursor on the same row.

| Upstream file | Symbol | Why it is there |
|---|---|---|
| `internal/ui/editor_inline.go` | `InlineSuggestion`, `SetInlineSuggestion`, `ClearInlineSuggestion`, `inlineTextAt`, `drawInlineSuggestion` | The whole feature: a cursor-anchored suggestion, drawn width-aware over the blank tail of the line with the active-line background. |
| `internal/ui/editor_widget.go` | fields `Inline`, `inlineLine` on `EditorPaneWidget` | Where the pane keeps the current suggestion. |
| `internal/ui/editor_widget_render.go` | the `inlineTextAt` block in `Render`, inside the per-row loop | Draws the ghost text once the row's cells and links are painted. |
| `internal/ui/editor_group.go` | `SwitchTab` → `ClearInlineSuggestion` | A suggestion belongs to one tab; switching tabs drops it. |
| `internal/plugin/lua_inline.go` | `setupInlineModule` | The `ttt.inline` Lua module, gated on `editor.decorations`. |
| `internal/plugin/plugin.go` | `SetInlineSuggestion`/`ClearInlineSuggestion` fields, `setupInlineModule` in `Init`/`InitFromSource`, teardown | Plugin host wiring; the fields are nil'd when the VM is destroyed. |
| `internal/plugin/sandbox.go` | `"ttt.inline"` in `allowedModules` | Without this `require` fails inside the sandbox. |
| `internal/app/commands_plugin.go` | `WirePlugin` closures; `ClearPluginSources` | Routes the Lua call to the editor group and clears the ghost text when a plugin is disabled, reloaded or uninstalled. |
| `internal/app/commands_debug.go` | `LoadPluginFromFile` → `p.Editor` | `--plugin` used to wire `ttt.editor` only after the Lua VM loaded, so a dev-loaded plugin saw `ttt.editor` as nil. Set it before `InitFromSource`, as the production path does. |
| `docs-web/src/content/docs/guides/plugin-authoring.md` | "Inline suggestions" section | The public contract; keep it in sync with any change. |

The plugin contract is exactly:

```lua
local inline = require("ttt.inline")
inline.set(text[, { style = "note" }])  -- first line is drawn after the cursor
inline.clear()
```

Semantics the plugin relies on: the suggestion is bound to the cursor position
and the line text at `set` time, so any edit or move invalidates it; the buffer,
undo stack and selection are never touched; nothing is drawn when real text
follows the cursor; `set("")` clears. Requires `editor.decorations`.

## Re-applying after an upstream import

1. `git apply -3 tweaks/0008-feat-editor-inline-suggestions.patch`. If it
   applies, skip to *Verification* — but check step 2's `require` list first:
   an upstream rename of a helper used by the patch can compile cleanly and
   still be wrong.
2. If it does not apply, redo it by hand in this order, using the symbol
   anchors above to find the spots (grep the symbol; upstream moves code
   often):
   - copy `editor_inline.go` next to `editor_widget.go`; it needs
     `textwidth` for the fullwidth-aware draw and `term.StyleActiveLine` for
     the background;
   - add the `Inline`/`inlineLine` fields to `EditorPaneWidget`;
   - paste the draw block into `Render`'s per-row loop, after the line's
     cells are drawn and before the `else` branch for rows past the end;
   - clear in `SwitchTab`;
   - add `lua_inline.go`, the two `Plugin` fields, the two `setupInlineModule`
     calls (both `Init` and `InitFromSource`), the module in
     `allowedModules`, and the `WirePlugin`/`ClearPluginSources` closures;
   - re-add the docs section.
3. Run `make test` and the checks below.

### Failure modes to check after a merge

- Ghost text missing but `Tab` still inserts: the draw block or its call was
  dropped; `ttt.inline.set` and `tests/e2e/tab_complete_test.go` will still
  pass only if the draw block is present, so run that test.
- Ghost text drawn over the user's code: an upstream change to how rows clip
  removed the "blank tail only" rule in `inlineTextAt`.
- Ghost text in the wrong column after tabs/fullwidth text: the draw must
  start at `bufColToVisualCol(cursor.Col) - Viewport.LeftCol`, never at the
  rune count.
- `require("ttt.inline")` fails: the sandbox's `allowedModules` entry is gone.

## Verification

```sh
go test ./internal/ui/ -run 'InlineSuggestion' -v
go test ./internal/plugin/ -run 'Inline' -v
go test ./tests/e2e/ -run 'TabComplete' -v
make lint
```

Real-binary check (needs LM Studio serving `qwen2.5-coder-3b`):

```sh
TTT_CONFIG_DIR=/tmp/ttt-tab bin/ttt --size 120x40 --plugin tweaks/tab-complete/init.lua \
  --exec "wait-for Explore; type src/main; wait 1200; screenshot /tmp/ghost.txt; key tab; screenshot /tmp/after.txt; quit"
```

`/tmp/ghost.txt` shows the dim continuation after the cursor; `/tmp/after.txt`
shows the same text as buffer content. If the ghost never appears: check
`resp.status` in the OUTPUT panel (`Tab Complete` logs requests only at
`warn`), the endpoint setting, and that the model name matches LM Studio's
loaded model.

## Limits (v1)

- One-line ghost text; a multi-line completion shows its first line plus ` ↵`
  and inserts in full on Tab.
- Only at the end of a line: the terminal cannot shift the rest of the line
  right, so a mid-line suggestion could only overwrite code.
- No word-by-word partial accept. No edit history, no next-edit jumping, no
  diagnostics context (Zed's stage 2/3 in `docs/reference.md`).
- Works in the normal editor pane; diff panes and word-wrapped panes do not
  draw suggestions.

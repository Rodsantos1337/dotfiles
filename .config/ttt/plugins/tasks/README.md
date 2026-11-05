# Dev — planning folder tab

A ttt sidebar tab that lists each workspace folder's `dev/` directory: epics,
tasks, decisions, templates. Clicking a file opens it as a normal editor tab, so
everything is editable, undoable and saveable like any other file.

```
~/.config/ttt/plugins/dev/
  plugin.ttt.json
  init.lua
  README.md
```

## Permissions

| Permission     | Why |
|----------------|-----|
| `panel.sidebar` | provides the **Dev** tab |
| `commands`      | `Dev: Show Planning Folder`, `Dev: Refresh` |
| `keybindings`   | `ctrl+k d` |
| `fs.read`       | lists and reads files under the workspace `dev/` |
| `editor.read`   | reads the active file path to locate the workspace on ttt 1.8.0 |
| `events.file`   | refreshes a badge when a planning doc is saved |
| `system.env`    | reads `$PWD` to locate the workspace on ttt 1.8.0 |

## Behaviour

- **One workspace folder with `dev/`** — its contents are the tree.
- **Several folders** — each folder is a root node; a folder without `dev/` shows
  a muted `no dev/` row.
- **No `dev/` anywhere** — empty state telling you to run `dev-init` in a terminal.
- **`dev/` exists but is empty** — `dev/ is empty`.
- **Badges** — the `status:` value from a markdown file's frontmatter
  (`todo`, `in-progress`, `blocked`, `done`); `done` files are dimmed.
- **Refresh** — the poll re-reads expanded directories every 2 s and redraws only
  when the listing changed; saving a file also refreshes its badge.
- Enter or a click on a file row opens it; arrows only move the selection.

## Known limits

- Not the core Explorer: no git-status tint, no file-type icons, no
  rename/delete/new-file actions.
- ttt 1.8.0 has no `ttt.automation` and no `ttt.focus_panel`, so this build finds
  a single workspace root (from `$PWD`, else from the active file) and
  `ctrl+k d` only refreshes and points at the tab. Newer ttt builds use the exact
  workspace list and focus the tab directly.
- Tree changes from outside ttt show up on the next poll, not instantly.

## Trying it

1. Restart ttt and **Allow** the Dev plugin in the approval dialog.
2. Click the **Dev** tab in the sidebar (widen the sidebar if it sits under `»`).

Verified against ttt v1.8.0 with:

```sh
TTT_CONFIG_DIR=/tmp/cfg ttt --size 140x40 \
  --plugin ~/.config/ttt/plugins/dev/init.lua \
  --exec 'wait 300; screenshot /tmp/screen.txt; quit'
```

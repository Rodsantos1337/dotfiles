# Everforest Green Dark — Dim

Custom darker Everforest setup for this machine. The desktop is unified on a
custom background ramp whose primary color is `#1e2326` (Everforest's dark-hard
`bg_dim` from the current sainnhe palette), chosen for its deeper look versus
both the old v1 hard (`#2b3339`) and the current v2 hard (`#272e33`) main
backgrounds.

No packaged theme files were modified. `/usr/share/themes/*` is stock
(`pacman -Qkk everforest-gtk-theme-git` reports `0 altered files`). All changes
live in user config or in a user-level copy of the theme, so package updates
never conflict.

## The color ramp

The installed `everforest-gtk-theme-git` (r79.9b8be4d6-1) ships only the current
palette. We shift every background-family color one step darker. Borders keep
the same contrast offset relative to the new main bg.

| Role                  | Old      | New      |
|-----------------------|----------|----------|
| main background       | #272e33  | #1e2326  |
| inputs / base         | #293136  | #232a2e  |
| wm buttons / hover    | #343a3e  | #2e383c  |
| borders / separators  | #434a4e  | #3a4141  |
| terminal black        | #475258  | #323c41  |

Foreground/accents are unchanged: fg `#d3c6aa`, green `#a7c080`, red `#e67e80`,
yellow `#dbbc7f`, blue `#7fbbb3`, purple `#d699b6`, aqua `#83c092`,
orange `#e69875`, greys `#7a8478` / `#859289`.

Palette reference: https://github.com/sainnhe/everforest (v1 source snapshot:
commit `2dd7dd9e96992f80596603807f9254f8d4ef90dd`, pre April-2021 rework).

## Per-component application

### GTK 3 / GTK 4

- Local theme copy at `~/.local/share/themes/Everforest-Green-Dark-Dim/`
  (copied from `/usr/share/themes/Everforest-Green-Dark`, ~2.7 MB).
- All `.css` and `.svg` assets under `gtk-3.0/`, `gtk-4.0/`, `gnome-shell/`
  rewritten with the ramp via sed (case-insensitive).
- `index.theme` renamed to `Everforest-Green-Dark-Dim`.
- Selected in four places:
  - `~/.config/gtk-3.0/settings.ini` → `gtk-theme-name=Everforest-Green-Dark-Dim`
  - `~/.config/gtk-4.0/settings.ini` → same
  - `~/.config/xsettingsd/xsettingsd.conf` → `Net/ThemeName "Everforest-Green-Dark-Dim"`,
    applied with `pkill -HUP xsettingsd`
  - dconf: `/org/gnome/desktop/interface/gtk-theme` = `'Everforest-Green-Dark-Dim'`
- Chromium-based browsers (Brave) follow this automatically when set to use the
  GTK+ theme; restart them to pick up changes.

### i3

- `~/.config/i3/config`: `$ever_bg` → `#1e2326`; client colors inherit it.
- Bar: `background`, `active_workspace`, `inactive_workspace` → `#1e2326`.
- dmenu (`$mod+d`): `-nb '#1e2326'`.
- Scripts using dmenu themes: `~/.config/i3/scripts/powermenu` and
  `~/.config/i3/scripts/power-profiles` (`-nb`/`-sf` → `#1e2326`).
- Validate with: `i3 -C -c ~/.config/i3/config`.

### alacritty

- `~/.config/alacritty/alacritty.toml`:
  - `colors.primary.background` → `#1e2326`
  - `colors.cursor.text` → `#1e2326`
  - `colors.normal.black` → `#323c41` (bright black stays `#475258`)
- Restart alacritty windows to apply.

### dunst

- `~/.config/dunst/dunstrc`:
  - `[urgency_low]` / `[urgency_normal]`: `background = "#1e2326"`
  - `[urgency_critical]`: `foreground = "#1e2326"` (on red)
- Apply: `systemctl --user restart dunst.service`

### opencode

- `~/.config/opencode/themes/everforest-dark-hard.json` — custom theme,
  schema https://opencode.ai/theme.json.
  - Backgrounds: `#1e2326` / panels `#232a2e` / borders `#3a4141`.
  - **Green-accent-only design**: all UI accents, markdown and syntax colors
    map to `#a7c080` + neutrals (`grey0`/`grey1`) to avoid eye strain.
  - Two semantic exceptions stay red: `error` (`#e67e80`) and the diff-removed
    family (`#4e3e43`), so failures/deletions remain recognizable.
- Selected via `"theme": "everforest-dark-hard"` in
  `~/.config/opencode/tui.json`. NB: the setting was originally added to
  `opencode.jsonc`, but opencode auto-migrated it into `tui.json` (its
  documented location) on next launch; the leftover backup is
  `opencode.jsonc.tui-migration.bak` and can be deleted.
- Verify inside opencode with `/themes`.

### Zed

- `~/.config/zed/themes/Everforest Dark Dim.json` — full theme definition with
  the identical ramp (UI, gutter, terminal ANSI, syntax).
- `~/.config/zed/settings.json` → `"dark": "Everforest Dark Dim"`
  (was `Everforest Dark Hard (material)`).
- Reload Zed to apply.

## Untouched / caveats

- `/usr/share/themes/Everforest-*` — stock, untouched.
- Icon theme `Everforest-Dark` and cursor theme `Adwaita` — unchanged.
- i3blocks config needed no changes (text-only, transparent over the bar).
### picom

- `~/.config/picom/picom.conf`: soft shadows (radius 8, opacity 0.35) +
  fast fading + `inactive-opacity 0.96`. No full-screen blur (RAM/CPU hog).
  Shadow color is plain black; there are no Everforest-tinted compositor
  colors to set.

### polybar (replaces i3bar)

- `~/.config/polybar/config.ini` + `launch.sh` (launched from i3 config).
- Bottom bar: `background #1e2326`, `foreground #d3c6aa`,
  `border #3a4141`, focused workspace green `#a7c080` on `#1e2326`,
  urgent `#e67e80`. Font GeistMono Nerd Font Mono 11.
- Old `bar {}` block kept commented in i3 config as fallback; `i3blocks.conf`
  retained but unused.

### rofi (launcher only, `$mod+d`)

- `~/.config/rofi/config.rasi` (`drun,run`, icons on) + `everforest-dim.rasi`
  (window `#1e2326`, inputbar `#232a2e`, border `#3a4141`,
  selected green `#a7c080` on `#1e2326`).
- Powermenu / power-profiles scripts stay on dmenu, so `dmenu` remains installed.
- Libadwaita apps (modern GNOME core apps) ignore `gtk-theme-name` entirely;
  they will not follow any of this. Nothing short of patching them fixes that.
- Truecolor terminal required for the opencode theme to render accurately.

## Rollback (per component)

| Component   | Rollback action                                                        |
|-------------|------------------------------------------------------------------------|
| GTK         | Point the three selection points back to `Everforest-Green-Dark`, then delete `~/.local/share/themes/Everforest-Green-Dark-Dim/` |
| i3          | Restore `#2b3339` for `$ever_bg`, dmenu, bar/workspace entries and the two power scripts |
| alacritty   | `background`/cursor text back to `#2b3339`, black back to `#475258`     |
| dunst       | Revert the two backgrounds / one foreground to `#2b3339`, restart service |
| opencode    | Remove `"theme"` line from `tui.json` (falls back to default) and/or delete the theme file |
| Zed         | Set dark theme back to `Everforest Dark Hard (material)`; optionally delete the local theme file |

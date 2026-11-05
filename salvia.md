# Sálvia

Custom dark grey setup for this machine, replacing the Everforest Dim setup.
Palette name: **Sálvia Cinza**. The desktop is unified on a custom background
ramp whose primary color is `#1b1c1c`, a neutral grey with no green or blue
cast. It is the lighter sibling of Sálvia Dim (`#0f1010`): more separation
between layers, less depth.

The house colors drive the accents: **sage** `#a8bf9c` is the primary accent
(focus, selection, prompts, links) and **amarelo torrado** `#dba53b` is the
secondary accent (warnings, highlights, syntax keywords).

No packaged theme files are modified. `/usr/share/themes/*` stays stock; all
changes live in user config or in a user-level copy of the theme, so package
updates never conflict.

## The color ramp

Every background-family color moves to a neutral grey ramp. Borders are lighter
than the surfaces so windows stay separated.

| Role                    | Stock Everforest  | Sálvia  | Note                              |
|-------------------------|-------------------|---------|-----------------------------------|
| deepest layer           | (none)            | #121313 | optional: terminal inset, gaps    |
| main background         | #272e33           | #1b1c1c |                                   |
| inputs / surface        | #293136           | #242626 |                                   |
| wm buttons / hover      | #343a3e           | #303231 | derived: midpoint surface/border  |
| borders / separators    | #434a4e           | #3b3e3c |                                   |
| terminal black          | #475258           | #2a2c2b |                                   |
| terminal bright black   | #475258           | #767974 |                                   |
| muted text              | #7a8478 / #859289 | #979a94 | about 6:1 on main bg              |
| foreground              | #ffffff           | #e8e6dc | softer to reduce glare            |

### Accents

| Role            | Stock Everforest | Sálvia  | Name            |
|-----------------|------------------|---------|-----------------|
| green (primary) | #a7c080          | #a8bf9c | sage            |
| yellow          | #dbbc7f          | #dba53b | amarelo torrado |
| red / error     | #e67e80          | #cf6f63 |                 |
| orange          | #e69875          | #d4806a | coral           |
| blue            | #7fbbb3          | #86a9c4 | sky             |
| aqua            | #83c092          | #8aa3ad | slate           |
| purple          | #d699b6          | #b09ac4 |                 |
| soft grey       | (none)           | #b9bbb3 | ash             |

### Terminal ANSI (16)

| #         | Normal  | Bright  |
|-----------|---------|---------|
| 0 black   | #2a2c2b | #767974 |
| 1 red     | #cf6f63 | #e08a7e |
| 2 green   | #9fb892 | #b4cba6 |
| 3 yellow  | #d6a33a | #e8bd5e |
| 4 blue    | #7a9fc0 | #9bbbd6 |
| 5 magenta | #b09ac4 | #c8b3d9 |
| 6 cyan    | #7fb5ab | #9ccbc1 |
| 7 white   | #c4c6bd | #eceae0 |

Design source: the "Sálvia Cinza" board in the Sálvia design canvas.

## Per-component application

### GTK 3 / GTK 4

- Local theme copy at `~/.local/share/themes/Salvia/`
  (copied from `/usr/share/themes/Everforest-Green-Dark`).
- All `.css` and `.svg` assets under `gtk-3.0/`, `gtk-4.0/`, `gnome-shell/`
  rewritten with the tables above via sed (case-insensitive). Backgrounds and
  accents map one to one. Review any `#ffffff` hits before accepting them, since
  some are intentional highlights and not text.
- `index.theme` renamed to `Salvia`.
- Selected in four places:
  - `~/.config/gtk-3.0/settings.ini` → `gtk-theme-name=Salvia`
  - `~/.config/gtk-4.0/settings.ini` → same
  - `~/.config/xsettingsd/xsettingsd.conf` → `Net/ThemeName "Salvia"`,
    applied with `pkill -HUP xsettingsd`
  - dconf: `/org/gnome/desktop/interface/gtk-theme` = `'Salvia'`
- Chromium-based browsers (Brave) follow this automatically when set to use the
  GTK+ theme; restart them to pick up changes.

### i3

- `~/.config/i3/config`: `$ever_bg` → renamed `$salvia_bg` = `#1b1c1c`; client
  colors inherit it.
- Client borders: focused `#a8bf9c`, unfocused `#3b3e3c`, urgent `#cf6f63`.
- dmenu (`$mod+d`): `-nb '#1b1c1c'`.
- Scripts using dmenu themes: `~/.config/i3/scripts/powermenu` and
  `~/.config/i3/scripts/power-profiles` (`-nb`/`-sf` → `#1b1c1c`).
- Validate with: `i3 -C -c ~/.config/i3/config`.

### kitty

- `~/.config/kitty/kitty.toml`:
  - `colors.primary.background` → `#1b1c1c`
  - `colors.primary.foreground` → `#e8e6dc`
  - `colors.cursor.text` → `#1b1c1c`
  - `colors.normal.*` and `colors.bright.*` → the ANSI table above
    (bright black moves to `#767974` so comments and autosuggestions stay readable)
- Restart kitty windows to apply.

### dunst

- `~/.config/dunst/dunstrc`:
  - `[urgency_low]` / `[urgency_normal]`: `background = "#1b1c1c"`,
    `foreground = "#e8e6dc"`, `frame_color = "#3b3e3c"`
  - `[urgency_critical]`: `background = "#cf6f63"`, `foreground = "#1b1c1c"`
- Apply: `systemctl --user restart dunst.service`

### opencode

- `~/.config/opencode/themes/salvia.json` — custom theme,
  schema https://opencode.ai/theme.json.
  - Backgrounds: `#1b1c1c` / panels `#242626` / borders `#3b3e3c`.
  - **Sage-accent-only design**: all UI accents, markdown and syntax colors
    map to `#a8bf9c` + neutrals (`#979a94` / `#b9bbb3`) to avoid eye strain.
  - Two semantic exceptions stay red: `error` (`#cf6f63`) and the diff-removed
    family (`#3a2625`, derived), so failures and deletions remain recognizable.
- Selected via `"theme": "salvia"` in `~/.config/opencode/tui.json`.
- Verify inside opencode with `/themes`.

### Zed

- `~/.config/zed/themes/Salvia.json` — full theme definition with the identical
  ramp (UI, gutter, terminal ANSI, syntax).
- Syntax roles: keywords amarelo `#dba53b`, strings sage `#a8bf9c`, functions
  sky `#86a9c4`, types slate `#8aa3ad`, numbers coral `#d4806a`, comments muted
  `#979a94`, text `#e8e6dc`.
- `~/.config/zed/settings.json` → `"dark": "Salvia"`
  (currently `Everforest Dark Dim`).
- Reload Zed to apply.

### picom

- `~/.config/picom/picom.conf` stays as is: soft shadows (radius 8,
  opacity 0.35) + fast fading + `inactive-opacity 0.96`.
- Shadow color is plain black; there are no Sálvia-tinted compositor colors
  to set.

### polybar

- `~/.config/polybar/config.ini`: `background #1b1c1c`, `foreground #e8e6dc`,
  `border #3b3e3c`, focused workspace sage `#a8bf9c` on `#1b1c1c`,
  urgent `#cf6f63`, warning states (low battery, high CPU) amarelo `#dba53b`.

### rofi (launcher only, `$mod+d`)

- `~/.config/rofi/salvia.rasi` (window `#1b1c1c`, inputbar `#242626`,
  border `#3b3e3c`, selected sage `#a8bf9c` with `#1b1c1c` text).
- Select it in `~/.config/rofi/config.rasi`.

## Untouched / caveats

- `/usr/share/themes/Everforest-*` — stock, untouched.
- Icon theme `Everforest-Dark` is green-tinted and may clash with the neutral
  greys; cursor theme `Adwaita` is unchanged. Swapping the icon theme is optional.
- i3blocks config needs no changes.
- Libadwaita apps (modern GNOME core apps) ignore `gtk-theme-name` entirely;
  they will not follow any of this.
- Truecolor terminal required for the opencode theme to render accurately.
- Bright black (`#767974`) is about 4:1 on the main background: fine for
  comments, dim for anything essential.

## Rollback (per component)

Rolling back returns to the Everforest Dim setup (`#1e2326` ramp).

| Component | Rollback action |
|-----------|-----------------|
| GTK       | Point the three selection points back to `Everforest-Green-Dark-Dim`, then delete `~/.local/share/themes/Salvia/` |
| i3        | Restore `#1e2326` for `$ever_bg`, dmenu, bar/workspace entries and the two power scripts |
| kitty     | `background`/cursor text back to `#1e2326`, black back to `#323c41`, bright black back to `#475258` |
| dunst     | Revert the backgrounds / critical foreground to `#1e2326`, restart service |
| opencode  | Set `"theme": "everforest-dark-hard"` in `tui.json`, and/or delete `salvia.json` |
| Zed       | Set dark theme back to `Everforest Dark Dim`; optionally delete the local theme file |
| polybar   | Restore `#1e2326` background and green `#a7c080` focus |
| rofi      | Point `config.rasi` back to `everforest-dim.rasi` |

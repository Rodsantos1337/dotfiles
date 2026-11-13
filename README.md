# dotfiles

rod's Salvia-Dim i3wm dotfiles (Fedora desktop + laptop).

For the full architecture, package inventory, keybindings, theming map, and
porting checklist, see [`dotfiles.md`](dotfiles.md).

## Layout

```
├── setup.sh                  # Fedora provisioning (packages, services, theming, then install.sh)
├── install.sh                # Symlink installer (shared, no packages). Requires --desktop|--laptop
├── lib/                      # Setup libraries
│   ├── common.sh             # Logging, idempotent git/systemd/link helpers
│   ├── packages.sh           # Fedora package arrays (base + laptop)
│   ├── services.sh           # systemd, ufw, display manager, laptop services
│   ├── browsers.sh           # Zen, Tailscale, opencode, fonts, Everforest icons
│   ├── dotfiles.sh           # Repo sync, install.sh, verification, auth, dev tools
│   └── theming.sh            # gsettings Salvia-Dim + PT keyboard
├── fedora/                   # Thin wrappers for backward compat
│   ├── install-fedora.sh
│   └── setup-laptop-fedora.sh
├── themes/                   # GTK/X11 themes (linked to ~/.local/share/themes/)
│   ├── Everforest-Green-Dark-Dim/
│   ├── Salvia/
│   └── Salvia-Dim/
├── wallpapers/               # Backgrounds (linked to ~/Pictures/)
├── .config/                  # Machine-agnostic configs (symlinked to ~/.config/)
│   ├── alacritty/
│   ├── disable-mouse-accel.sh
│   ├── dunst/
│   ├── flameshot/            # flameshot-desktop.ini, flameshot-laptop.ini
│   ├── fontconfig/
│   ├── gamemode.ini
│   ├── gtk-3.0/
│   ├── gtk-4.0/
│   ├── i3/
│   │   ├── config
│   │   ├── monitors-desktop   # linked as ~/.config/i3/local on desktop
│   │   ├── monitors-laptop    # linked as ~/.config/i3/local on laptop
│   │   └── scripts/           # 12 utility scripts (see below)
│   ├── kitty/
│   ├── mimeapps.list
│   ├── nvim/
│   ├── opencode/
│   ├── picom/
│   ├── polybar/
│   ├── qutebrowser/
│   ├── rofi/
│   ├── systemd/
│   ├── ttt/
│   ├── user-dirs.dirs
│   ├── user-dirs.locale
│   ├── xsettingsd/
│   └── zed/
├── .bashrc
├── .zshrc
├── .fehbg
├── .xprofile
├── .Xresources
├── .gitconfig
├── .gitignore
├── .freebuff/
├── salvia.md                 # Salvia theme reference
├── salvia-dim.md             # Salvia-Dim theme reference
├── everforest-green-dark-dim.md  # Everforest theme reference
└── dotfiles.md               # Full architecture doc
```

### `.config/i3/scripts/` (12 scripts)

| Script | Purpose |
|--------|---------|
| `battery` | Battery status for polybar |
| `brightness` | Brightness control (up/down/get) |
| `fresh-vault-toggle` | Toggle Obsidian fresh vault |
| `gaming-toggle` | Gaming mode (disables compositor, etc.) |
| `obsidian-toggle2` | Toggle Obsidian window |
| `power-profiles` | Switch power profile (balanced/performance/power-saver) |
| `powermenu` | Rofi-based power menu (lock/suspend/hibernate/reboot/shutdown) |
| `pp-indicator` | Power profile indicator for polybar |
| `refresh-toggle` | Toggle monitor refresh rate |
| `ttt-toggle` | Toggle ttt (terminal-tui-timer) |
| `ttt-vault-toggle` | Toggle ttt vault |
| `volume` | Volume control (up/down/mute/get) |

## Fresh Machine

```sh
git clone https://github.com/Rodsantos1337/dotfiles.git ~/dotfiles
~/dotfiles/setup.sh --laptop    # laptop
~/dotfiles/setup.sh --desktop   # desktop
```

Symlinks only (no packages):

```sh
~/dotfiles/install.sh --laptop
~/dotfiles/install.sh --desktop
```

Setup is idempotent; re-running is safe. The i3 monitor variant follows the
same flag (`~/.config/i3/local -> monitors-<variant>`). Flameshot config is
also variant-specific (`~/.config/flameshot/flameshot.ini -> flameshot-<variant>.ini`).
The repo must be public before a fresh box can clone it. The repo stays public
by default; add `--privatize` to flip it back to private at the end.

## Portable bootstrap binary

`bootstrap/` is a Go program that performs the whole setup - packages,
accounts, symlinks, theming, services - behind a TUI, so a fresh machine needs
one file instead of a shell checkout.

Build a static binary for the pendrive:

```sh
cd bootstrap
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath \
  -ldflags "-s -w -X main.commit=$(git rev-parse --short HEAD)" \
  -o bin/bootstrap .
```

Then, from the pendrive:

```sh
./bootstrap                    # TUI: pick desktop/laptop, pick steps, watch progress
./bootstrap plan               # every step, what it does, whether it is selected
./bootstrap apply --laptop     # unattended run
./bootstrap apply --dry-run    # print the commands, change nothing
./bootstrap link --desktop     # symlinks only (same result as install.sh)
./bootstrap verify             # check that the symlinks are in place
```

Flags: `--variant`, `--groups`, `--only`, `--exclude`, `--dotfiles-dir`,
`--upgrade` (full `dnf upgrade`, off by default) and `--privatize`.

Every step checks whether its work is already done, so re-running is safe.
Interactive steps (GitHub device login, `tailscale up`) hand the terminal back
to you. Each run logs to
`~/.local/state/dotfiles-bootstrap/run-<timestamp>.log`. `setup.sh` and
`install.sh` keep working on their own; the binary is additive.

## Sensible Defaults

- **Alt + Left/Right Arrow**: Move cursor by one word
- **Ctrl + Left/Right Arrow**: Move cursor to beginning/end of line
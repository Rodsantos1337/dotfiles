# dotfiles

rod's Salvia-Dim i3wm dotfiles (Fedora desktop + laptop).

For the full architecture, package inventory, keybindings, theming map, and
porting checklist, see [`dotfiles.md`](dotfiles.md).

## Layout

- `setup.sh` — Fedora provisioning for desktop/laptop (packages, browsers,
  services, theming, then calls `install.sh`). Requires `--desktop` or
  `--laptop`, no auto-detection.
- `install.sh` — symlink installer, shared by both machines (installs no
  packages; run `setup.sh` for that). Requires `--desktop` or `--laptop`
  for the i3 monitor + flameshot variants.
- `lib/` — setup libraries (`common`, `packages`, `services`, `browsers`,
  `dotfiles`, `theming`)
- root dotfiles (machine-agnostic): `.config/`, `.bashrc`, `.zshrc`, `.fehbg`,
  `.xprofile`, `.Xresources`, `themes/`, `wallpapers/`
- `fedora/` — thin wrappers around `../setup.sh` (backward compat)
- `restore-desktop.sh`, `fix-boot-i3.sh` — one-shot Fedora rescue scripts
  (broken desktop / LightDM greeter fixes)

## Fresh machine

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
same flag (`~/.config/i3/local -> monitors-<variant>`). The repo must be
public before a fresh box can clone it. The repo stays public by default;
add `--privatize` to flip it back to private at the end.

Sensible Defaults:
Alt + Left/Right Arrow: Move cursor by one word.
Ctrl + Left/Right Arrow: Move cursor to the beginning/end of the line.

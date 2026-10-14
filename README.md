# dotfiles

rod's Everforest i3wm dotfiles.

## Layout

- `setup.sh` — unified provisioning for Arch/Fedora, desktop/laptop
  (packages, browsers, services, theming, then calls `install.sh`)
- `install.sh` — symlink installer, shared by every platform (installs no
  packages; run `setup.sh` for that)
- `lib/` — setup libraries (`common`, `packages`, `services`, `browsers`,
  `dotfiles`, `theming`)
- root dotfiles (distro-agnostic): `.config/`, `.bashrc`, `.zshrc`, `.fehbg`,
  `.xprofile`, `.Xresources`, `themes/`, `wallpapers/`
- `arch/`, `fedora/` — thin wrappers around `../setup.sh` (backward compat).
  See `arch/archsetup.md` for bootstrap.

## Fresh machine

```sh
git clone https://github.com/Rodsantos1337/dotfiles.git ~/dotfiles
~/dotfiles/setup.sh --fedora --laptop    # this laptop (hostname fedora: pass --laptop explicitly)
~/dotfiles/setup.sh --fedora --desktop   # other machine (desktop)
```

Symlinks only (no packages):

```sh
~/dotfiles/install.sh --laptop
~/dotfiles/install.sh --desktop
```

Setup is idempotent; re-running is safe. Always pass `--laptop` /
`--desktop` explicitly — auto-detection treats hostname `fedora*` as
desktop, which is wrong on the laptop. The i3 monitor variant follows the
same flag (`~/.config/i3/local -> monitors-<variant>`). The repo must be
public before a fresh box can clone it (bootstrap details in
`arch/archsetup.md`).

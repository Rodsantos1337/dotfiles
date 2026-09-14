# dotfiles

rod's Everforest i3wm dotfiles.

## Layout

- `install.sh` — symlink installer, shared by every platform (installs no
  packages; run the setup script for that)
- root dotfiles (distro-agnostic): `.config/`, `.bashrc`, `.fehbg`,
  `.xprofile`, `.Xresources`, `themes/`, `wallpapers/`
- `arch/` — Arch provisioning: `setup.sh` (desktop), `setup-laptop.sh`
  (Gigabyte G5 KF). See `arch/archsetup.md` first.
- `fedora/` — Fedora provisioning: `install-fedora.sh` (desktop),
  `setup-laptop-fedora.sh` (laptop)

## Fresh machine

```sh
git clone https://github.com/Rodsantos1337/dotfiles.git ~/dotfiles
~/dotfiles/arch/setup.sh          # Arch
~/dotfiles/fedora/install-fedora.sh  # Fedora
```

Setup scripts are idempotent; re-running is safe. On a laptop use the
`-laptop` variant. The repo must be public before a fresh box can clone it
(bootstrap details in `arch/archsetup.md`).

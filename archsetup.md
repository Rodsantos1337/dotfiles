# archsetup.md

## Purpose

Notes for provisioning a fresh Arch (archinstall i3-wm profile) machine.
The authoritative, executable version of everything below is **`setup.sh`
in the dotfiles repo** (`https://github.com/Rodsantos1337/dotfiles`) —
this doc explains the *why* and records pitfalls.

New-machine flow:

```
sudo pacman -S --needed git
git clone https://github.com/Rodsantos1337/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./setup.sh
```

`setup.sh` = steps 1–6 below. `install.sh` (called at the end) symlinks
the dotfiles into `$HOME` with backups; it installs nothing.

---

## 1. pacman packages

All installed with `--needed`, so the script is safe on any machine
regardless of what archinstall already provided.

- **base-devel, git** — build yay from AUR; clone this repo
- **python-gobject** — listed as *optional* dep of power-profiles-daemon,
  but `powerprofilesctl` requires it (else `ModuleNotFoundError:
  gi.repository`). Must be explicit.
- **Session/WM:** i3-wm, i3blocks, dmenu, i3lock, xss-lock, ly
  (`ly` = the display manager / login screen), xorg-server, xorg-xinit,
  xorg-xrandr, **xorg-xinput** (mouse-accel script), xorg-xrdb (.Xresources)
- **System UI:** alacritty, dunst, picom, xsettingsd, feh, flameshot,
  network-manager-applet, power-profiles-daemon, lm_sensors, pavucontrol
- **Fonts:** otf-commit-mono-nerd (family `CommitMono Nerd Font Mono`,
  used everywhere), inter-font
- **Apps:** firefox, thunar, obsidian, zed, opencode, nano
  (obsidian/zed/opencode are in `extra` now — no AUR needed)
- **Tools:** htop, wget, github-cli, ufw, bluez-utils, smartmontools,
  zram-generator, efibootmgr

Not in the list (archinstall/hardware territory): kernel (linux-zen),
GPU driver (nvidia-open-dkms), intel-ucode, sof-firmware.

Removed vs old setups: i3status (use i3blocks), vim (nano + zed),
dex/playerctl/rofi/greenclip (unused).

## 2. yay

Built from AUR only if `yay` isn't already present.
`go` is a makedepends of the yay PKGBUILD — `makepkg -s` pulls it.
Build happens in `/tmp`; install with `-i` in the same run (/tmp is
wiped on reboot).

## 3. AUR packages (via yay)

brave-bin, everforest-gtk-theme-git, everforest-icon-theme-git
(the everforest theme pulls gtk2 + gtk-engine-murrine automatically).

## 4. Services

`sudo systemctl enable --now power-profiles-daemon`
(`--now` also starts it this session, no reboot needed).

## 5. gsettings (dconf)

The Everforest GTK theme alone is NOT enough — dconf stays at
Adwaita/default(light) and portal-aware apps (Firefox "System theme —
auto") flip to light. setup.sh sets:

```
gsettings set org.gnome.desktop.interface gtk-theme 'Everforest-Green-Dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-size 14
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.touchpad accel-profile 'flat'
```

## 6. Dotfiles

Clone `https://github.com/Rodsantos1337/dotfiles.git` to `~/dotfiles`
(pull if it exists), then run `install.sh`.

---

## Pitfalls / notes

- python-gobject skipped by pacman -> powerprofilesctl breaks (see #1)
- /tmp yay build wiped on reboot -> build+install same run
- Flameshot v14 uses XDG portal for capture even on X11 -> breaks on bare
  i3. Fixed via `~/.config/flameshot/flameshot.ini`:
  `[General] useX11LegacyScreenshot=true` (+ `captureActiveMonitor=true`)
  — tracked in the dotfiles repo, nothing to do manually.
- Cursor size lives in 5 places (gtk-3.0/gtk-4.0 settings.ini,
  xsettingsd.conf, gsettings cursor-size, .Xresources Xcursor.size +
  XCURSOR_SIZE in .xprofile). All set to **14**, theme Adwaita.
- Font = CommitMono Nerd Font Mono everywhere at 11 (dunst 9.5).
  Do NOT install plain jetbrains mono; fontconfig aliases
  `JetBrains Mono` -> nerd variant for old configs.
- Monitors: intentionally NOT configured in i3 config — left to i3/xrandr
  auto-detect so the same dotfiles work on desktop and laptop.

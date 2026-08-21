# archsetup.md

What `archinstall` (i3 profile) already gives you, what `setup.sh` adds on
top, and the few things that stay manual. Read once before running
`./setup.sh` on a fresh machine.

## archinstall covers (setup.sh does NOT repeat these)

- **PipeWire audio stack** — `pipewire`, `wireplumber`, `pipewire-alsa`,
  `pipewire-pulse` (+ `libpulse`, which provides `pactl` used by i3 volume keys)
- **zram swap** — installs `zram-generator` and writes
  `/etc/systemd/zram-generator.conf`
- **Display manager** — ships lightdm enabled by default. This setup prefers
  ly; `setup.sh` only enables `ly@tty1` if no display-manager is enabled yet
  (lightdm stays installed but dormant)
- **Kernel/GPU/firmware territory** — linux/linux-zen, nvidia-open-dkms,
  intel-ucode, sof-firmware: never in setup.sh
- **/etc/ly/config.ini** — generated at install time. If you customize it,
  save it to the dotfiles and wire it into setup.sh yourself

## setup.sh handles

1. All pacman packages (`--needed`, safe to re-run) — WM session stack, apps,
   fonts (GeistMono Nerd Font Mono), tools, portals/xdg for screen sharing
   and file dialogs
2. Builds yay from AUR, then AUR packages: brave-bin,
   everforest-gtk-theme-git. **No icon theme package** — icons stay stock
   Adwaita (see `.config/xsettingsd/xsettingsd.conf`)
3. Services: power-profiles-daemon, ufw; enables `ly@tty1` only if no other
   display manager is active
4. gsettings theming (GTK theme + color-scheme so portal-aware apps like
   Firefox don't flip to light mode)
5. Git identity hardcoded (Rodsantos1337) — edit if it changes
6. `gh auth login -w` browser flow, skipped if already authenticated
7. Clones this repo to ~/dotfiles and runs install.sh (symlinks everything)

## Known inert bits

- `/etc/ly/config.ini` brightness keys reference `brightnessctl`, which is
  deliberately not installed (monitor brightness is changed on the monitor
  itself). The keybinds silently do nothing.

## Manual steps after setup.sh

- `opencode auth` — API key login, interactive
- Anything machine-specific goes in `~/.config/i3/local` (gitignored via the
  repo's `include ~/.config/i3/local*` line) — e.g. monitor layout:
  `xrandr --output HDMI-0 --pos 0x0 --output DP-0 --primary --pos 1360x0`

## Old-machine cleanup (one-time)

- `sudo pacman -Rns everforest-icon-theme-git` if it was installed before
  icons moved to Adwaita

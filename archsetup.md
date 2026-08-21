# archsetup.md

What `archinstall` (i3 profile) already gives you, what `setup.sh` adds on
top, and the few things that stay manual. Read once before running
`./setup.sh` on a fresh machine.

## Bootstrap (fresh machine)

The repo idles at **private**, so a fresh box can't clone it without auth.
Before reinstalling:

1. Set github.com/Rodsantos1337/dotfiles to public (Settings → General →
   Danger Zone → Change visibility)
2. After archinstall: `sudo pacman -S --needed git`
3. `git clone https://github.com/Rodsantos1337/dotfiles.git ~/dotfiles`
4. `~/dotfiles/setup.sh`

Brave lands in step 3 of setup.sh, so the step-6 `gh auth login -w` has a
browser to open (and wires the HTTPS credential helper used by the private
quill clone in step 8). On success, setup.sh flips the repo back to private
in step 9 — if the run fails midway, flip it back manually.


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
   everforest-icon-theme-git (icons only — the GTK theme is NOT packaged;
   the custom `Everforest-Green-Dark-Dim` theme is vendored in this repo
   under `themes/` and symlinked by install.sh)
3. Services: power-profiles-daemon, ufw; enables `ly@tty1` only if no other
   display manager is active
4. gsettings theming (custom `Everforest-Green-Dark-Dim` GTK theme +
   `Everforest-Dark` icons + color-scheme so portal-aware apps like
   Firefox don't flip to light mode)
5. Git identity hardcoded (Rodsantos1337) — edit if it changes
6. `gh auth login -w` browser flow, skipped if already authenticated
7. Clones this repo to ~/dotfiles and runs install.sh (symlinks everything)
8. quill dev install: clones `~/base/quill` (HTTPS via the gh credential
   helper from step 6) and `pipx install -e` it — skipped if already present
9. Flips the dotfiles repo back to private (only reached on full success)

## Known inert bits

- `/etc/ly/config.ini` brightness keys reference `brightnessctl`, which is
  deliberately not installed (monitor brightness is changed on the monitor
  itself). The keybinds silently do nothing.

## Manual steps after setup.sh

- `opencode auth` — API key login, interactive
- Anything machine-specific goes in `~/.config/i3/local` (gitignored via the
  repo's `include ~/.config/i3/local*` line) — e.g. monitor layout:
  `xrandr --output HDMI-0 --pos 0x0 --output DP-0 --primary --pos 1360x0`

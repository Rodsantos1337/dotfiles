# archsetup.md

What `archinstall` (i3 profile) already gives you, what `setup.sh` adds on
top, and the few things that stay manual. Read once before running
`./arch/setup.sh` on a fresh machine.

## Bootstrap (fresh machine)

The repo is public by default. If it was flipped private, set it back to
public before reinstalling (Settings → General → Danger Zone → Change
visibility). Then:

1. After archinstall: `sudo pacman -S --needed git`
2. `git clone https://github.com/Rodsantos1337/dotfiles.git ~/dotfiles`
3. `~/dotfiles/arch/setup.sh`

Zen lands in step 3 of setup.sh, so the step-6 `gh auth login -w` has a
browser to open (and wires the HTTPS credential helper used by the private
quillcode clone in step 8). setup.sh only flips the repo back to private
when run with `--privatize`.

### Laptop variant: `setup-laptop.sh`

On the **Gigabyte G5 KF** run `./setup-laptop.sh` instead. It is setup.sh
plus fan control + keyboard backlight:

- `linux-zen-headers` (DKMS needs headers matching the running zen kernel)
  and `tuxedo-drivers-dkms` (clevo_acpi/tuxedo_io/tuxedo_keyboard)
- Clones `fans-g5-kf` and `kbl` to `~/src/` and runs each repo's own
  idempotent `sudo ./install.sh` (binaries to /usr/local/bin, scoped
  NOPASSWD sudoers rules), then enables `fans-guard`
- If `clevo_acpi` was half-loaded during install, one reboot finishes
  binding — verify with `fans status` (`hwcheck 1`)

Everything else in this document applies to both variants.


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
2. Builds yay from AUR, then AUR packages: zen-browser-bin,
   everforest-icon-theme-git (icons only — the GTK theme is NOT packaged;
   the custom `Everforest-Green-Dark-Dim` theme is vendored in this repo
   under `themes/` and symlinked by install.sh)
3. Services: power-profiles-daemon, ufw; enables `ly@tty1` only if no other
   display manager is active. The current power profile shows in the i3bar
   (`[power-profile]` block in i3blocks.conf); `$mod+Shift+p` switches it and
   refreshes the bar via SIGRTMIN+2
4. gsettings theming (custom `Everforest-Green-Dark-Dim` GTK theme +
   `Everforest-Dark` icons + color-scheme so portal-aware apps like
   Firefox don't flip to light mode)
5. Git identity hardcoded (Rodsantos1337) — edit if it changes
6. `gh auth login -w` browser flow, skipped if already authenticated
7. Clones this repo to ~/dotfiles and runs install.sh (symlinks everything)
8. quillcode dev install: clones `~/base/quillcode` (HTTPS via the gh
   credential helper from step 6) and installs cline globally
9. Flips the dotfiles repo back to private only with `--privatize`

## Known inert bits

- `/etc/ly/config.ini` brightness keys reference `brightnessctl`; those only
  apply on the login screen. Day-to-day screen brightness is handled by i3's
  `XF86MonBrightnessUp/Down` binds running `.config/i3/scripts/brightness`,
  which shows a dunst progress-bar OSD. Its deps (`brightnessctl`,
  `libnotify`) are installed by setup.sh — note neither is provided by
  archinstall's i3 profile (it ships only i3-wm/i3lock/i3status/i3blocks/
  xss-lock/xterm/lightdm/dmenu), and `libnotify` previously arrived only
  as a transitive dependency of thunar.

## Manual steps after setup.sh

- `opencode auth` — API key login, interactive
- Anything machine-specific goes in `~/.config/i3/local` (gitignored via the
  repo's `include ~/.config/i3/local*` line) — e.g. monitor layout:
  `xrandr --output HDMI-0 --pos 0x0 --output DP-0 --primary --pos 1360x0`

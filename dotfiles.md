# dotfiles.md

High-fidelity reference for this repository. Use `README.md` for the short
quick start and this file for the full architecture, inventory, and porting
checklist.

Snapshot: working tree as of 2026-11-04, base commit `a7fedb2`, 466 tracked
files. Uncommitted drift is listed in [Drift snapshot](#15-drift-snapshot).

## 1. Purpose and design

This repo provisions and configures an X11 i3 desktop on Arch Linux or Fedora,
for either a desktop or a laptop. The visual identity is a custom Everforest
Green Dark Dim palette with `#1e2326` as the main background.

Design invariants:

- Symlink based. `install.sh` links configs from the repo into `$HOME`; it does
  not copy them.
- Idempotent. Provisioning and linking are safe to re-run. Existing real files
  are backed up before being replaced.
- Two-layer install. `setup.sh` handles packages, services, external tools and
  theming. `install.sh` only handles symlinks.
- Per-machine variants. Desktop and laptop share one repo but differ in monitor
  layout, Flameshot save path, laptop power/fan tooling, and a few services.
- Everforest Dim everywhere. i3, GTK, Xresources, polybar, rofi, dunst, picom,
  terminals, browser, editors, and notification UI use the same ramp.
- Public-by-default repo. Fresh machines can clone without credentials. The
  repo is only flipped private when `setup.sh --privatize` is passed.

## 2. Quick start

Fresh machine:

```sh
git clone https://github.com/Rodsantos1337/dotfiles.git ~/dotfiles
~/dotfiles/setup.sh --laptop    # laptop
~/dotfiles/setup.sh --desktop   # desktop
```

Symlinks only, no packages:

```sh
~/dotfiles/install.sh --laptop
~/dotfiles/install.sh --desktop
```

The variant flag is required on both `setup.sh` and `install.sh` - there is
no hostname auto-detection.

After provisioning, log out and back in, or press `$mod+Shift+r` in i3.
Interactive steps that remain manual: `gh auth login`, `opencode auth`,
`sudo tailscale up`, and Syncthing device pairing.

## 3. Provisioning architecture

```text
setup.sh --desktop|--laptop [--privatize] [--no-verify]
  |
  +-- source lib/common.sh      logging, idempotent git/systemd/link helpers
  +-- source lib/packages.sh    Fedora package arrays (base + laptop)
  +-- source lib/services.sh    systemd + ufw + display manager + laptop services
  +-- source lib/browsers.sh    Zen, Tailscale, opencode, fonts, Everforest icons
  +-- source lib/dotfiles.sh    repo sync, install.sh, verification, auth, dev tools
  +-- source lib/theming.sh     gsettings Salvia-Dim + PT keyboard
  |
  +-- system setup
  |     upgrade, RPM Fusion, Zen COPR, dnf packages, third-party apps
  |
  +-- shared setup
        git identity, gh auth, ttt, marksman, llmserve,
        tailscale auth, sync repo, run install.sh, opencode deps,
        verify links, check stale paths, apply theming, set PT keyboard,
        set zsh shell, enable services, enable display manager,
        optionally privatize repo
```

Useful flags:

| Flag | Effect |
| --- | --- |
| `--desktop` / `--laptop` | Machine variant (required): monitor layout, flameshot config, laptop packages |
| `--no-verify` | Skip symlink and stale-path verification |
| `--privatize` | Flip `Rodsantos1337/dotfiles` private on success |
| `--no-privatize` | Keep public (default) |
| `-h`, `--help` | Print usage |

## 4. Desktop / laptop variant matrix

| Area | Desktop | Laptop |
| --- | --- | --- |
| Package manager | dnf + COPR | dnf + COPR |
| Display manager | existing, else install `lightdm` | existing, else install `lightdm` |
| Browser | `zen-browser` (COPR) | same |
| Terminal packages | kitty | kitty |
| Extra browser package | qutebrowser | qutebrowser |
| Laptop packages | none | `thermald`, `powertop`, `acpi` |
| Firewall | ufw, firewalld disabled | ufw, firewalld disabled |
| Monitor layout | DP-0 + HDMI-0 | eDP-1 144Hz |
| Flameshot path | `/home/rod-desktop/base/ACI/screenshots` | `/home/rod/base/ACI/screenshots` |

The fedora wrappers are compatibility shims:

| Wrapper | Expands to |
| --- | --- |
| `fedora/install-fedora.sh` | `setup.sh --desktop` |
| `fedora/setup-laptop-fedora.sh` | `setup.sh --laptop` |

## 5. Repository map

### Top level

| Path | Role |
| --- | --- |
| `setup.sh` | Fedora provisioner: variant, packages, services, tools, theming |
| `install.sh` | Symlink installer shared by both machines. No package installs |
| `lib/common.sh` | Logging, idempotent git/systemd/link helpers |
| `lib/packages.sh` | Fedora package arrays and getters |
| `lib/services.sh` | Common, display-manager, and laptop service logic |
| `lib/browsers.sh` | Zen, Tailscale, opencode, Nerd Fonts, Everforest icon installs |
| `lib/dotfiles.sh` | Repo sync, `install.sh` runner, verification, auth, external dev tools |
| `lib/theming.sh` | gsettings Salvia-Dim application and PT keyboard layout |
| `fedora/*.sh` | Backward-compatible wrappers around `../setup.sh` |
| `restore-desktop.sh` | Fedora recovery script for a broken display manager or missing X stack |
| `fix-boot-i3.sh` | Fedora boot fix: LightDM greeter, i3 session, wallpaper, plymouth |
| `everforest-green-dark-dim.md` | Palette reference and per-component theming notes |
| `themes/` | Vendored GTK themes: `Everforest-Green-Dark-Dim`, `Salvia-Dim` (active), `Salvia` |
| `wallpapers/*.jpg` | Wallpapers linked into `~/Pictures` |
| `.bashrc`, `.zshrc` | Shell aliases, PATH, fzf, zoxide, power toggles, editor env |
| `.xprofile` | X session PATH, cursor size, PT keyboard, Xresources merge |
| `.Xresources` | Xft rendering and cursor settings |
| `.gitconfig` | Git identity and GitHub credential helper via `gh` |
| `.fehbg` | Last wallpaper command generated by `feh` |
| `.gitignore` | Editor junk, backups, Python/Node artifacts, ttt state, syncthing, quill |

### `.config`

| Path | Role |
| --- | --- |
| `alacritty/alacritty.toml` | Alacritty colors, GeistMono font, padding |
| `disable-mouse-accel.sh` | Sets flat mouse/touchpad acceleration via gsettings and xinput |
| `dunst/dunstrc` | Everforest notification daemon, bottom-right, follow mouse |
| `flameshot/flameshot-desktop.ini` | Desktop Flameshot config, save path under `/home/rod-desktop` |
| `flameshot/flameshot-laptop.ini` | Laptop Flameshot config, save path under `/home/rod` |
| `fontconfig/fonts.conf` | JetBrainsMono Nerd Font Mono as sans/serif/monospace, sharp LCD settings |
| `gamemode.ini` | GameMode hooks kill picom on start and restore it on end |
| `gtk-3.0/settings.ini` | GTK3 theme, icons, Inter 12, Adwaita cursor 14 |
| `gtk-4.0/settings.ini` | GTK4 theme, icons, JetBrainsMono 11, cursor 16 |
| `i3/config` | Main i3 config: startup, keybindings, colors, scratchpads, screenshots |
| `i3/monitors-desktop` | xrandr layout for DP-0 + HDMI-0 |
| `i3/monitors-laptop` | xrandr layout for eDP-1 at 144Hz |
| `i3/scripts/` | Brightness, power, refresh, gaming, scratchpad, volume, battery scripts |
| `kitty/kitty.conf` | Kitty colors, GeistMono, tabs, keymaps |
| `mimeapps.list` | Zen as default for http, https, and HTML |
| `nvim/` | LazyVim setup with Everforest colorscheme and clangd extra |
| `opencode/` | Theme, TUI plugin, plugin dependency, AGENTS.md style guide |
| `picom/picom.conf` | Shadows, fading, rounded corners, animations, no blur, GLX |
| `polybar/config.ini` | Bottom bar, modules, Everforest palette, tray on primary only |
| `polybar/launch.sh` | Launches one tray bar and tray-less bars per monitor |
| `qutebrowser/config.py` | Everforest theme, vim keys, adblock, privacy, session save |
| `rofi/config.rasi` | drun/run launcher with Everforest theme and icons |
| `rofi/everforest-dim.rasi` | Rofi Everforest Dim theme |
| `systemd/user/` | AppImageLauncher user unit and enabled-user-unit symlinks |
| `ttt/` | ttt editor theme, settings, keybindings, LSP and task plugins |
| `user-dirs.dirs`, `user-dirs.locale` | XDG home directory layout and locale |
| `xsettingsd/xsettingsd.conf` | X settings daemon theme, icons, fonts, cursor |
| `zed/settings.json` | Zed theme, telemetry off, font sizes |
| `zed/themes/Everforest Dark Dim.json` | Local Zed theme definition |

## 6. Symlink contract

`install.sh` uses `MAPPINGS`. A mapping without `:` keeps the same relative
path under `$HOME`. A mapping with `:` maps `repo/path:home/path`.

| Repo path | Deployed path |
| --- | --- |
| `.xprofile` | `~/.xprofile` |
| `.Xresources` | `~/.Xresources` |
| `.bashrc` | `~/.bashrc` |
| `.zshrc` | `~/.zshrc` |
| `.fehbg` | `~/.fehbg` |
| `wallpapers/bg.jpg` | `~/Pictures/bg.jpg` |
| `wallpapers/bg-old.jpg` | `~/Pictures/bg-old.jpg` |
| `wallpapers/new.jpg` | `~/Pictures/new.jpg` |
| `wallpapers/bg-newer.jpg` | `~/Pictures/bg-newer.jpg` |
| `.config/i3/config` | `~/.config/i3/config` |
| `.config/i3/scripts` | `~/.config/i3/scripts` |
| `.config/kitty` | `~/.config/kitty` |
| `.config/dunst` | `~/.config/dunst` |
| `.config/fontconfig` | `~/.config/fontconfig` |
| `.config/gtk-3.0/settings.ini` | `~/.config/gtk-3.0/settings.ini` |
| `.config/gtk-4.0/settings.ini` | `~/.config/gtk-4.0/settings.ini` |
| `.config/opencode` | `~/.config/opencode` |
| `.config/picom` | `~/.config/picom` |
| `.config/polybar` | `~/.config/polybar` |
| `.config/rofi` | `~/.config/rofi` |
| `.config/ttt` | `~/.config/ttt` |
| `.config/nvim` | `~/.config/nvim` |
| `.config/zed` | `~/.config/zed` |
| `.config/alacritty` | `~/.config/alacritty` |
| `.config/qutebrowser/config.py` | `~/.config/qutebrowser/config.py` |
| `.config/xsettingsd` | `~/.config/xsettingsd` |
| `.config/disable-mouse-accel.sh` | `~/.config/disable-mouse-accel.sh` |
| `.config/mimeapps.list` | `~/.config/mimeapps.list` |
| `.config/user-dirs.dirs` | `~/.config/user-dirs.dirs` |
| `.config/user-dirs.locale` | `~/.config/user-dirs.locale` |
| `.config/gamemode.ini` | `~/.config/gamemode.ini` |
| `.config/systemd` | `~/.config/systemd` |
| `.gitconfig` | `~/.gitconfig` |
| `themes/Everforest-Green-Dark-Dim` | `~/.local/share/themes/Everforest-Green-Dark-Dim` |
| `themes/Salvia-Dim` | `~/.local/share/themes/Salvia-Dim` (active GTK theme) |
| `themes/Salvia` | `~/.local/share/themes/Salvia` |

Special variant links:

| Repo source | Deployed path | Selected by |
| --- | --- | --- |
| `.config/i3/monitors-<variant>` | `~/.config/i3/local` | `--desktop` or `--laptop` |
| `.config/flameshot/flameshot-<variant>.ini` | `~/.config/flameshot/flameshot.ini` | `--desktop` or `--laptop` |

Behavior:

- Already-correct symlinks are reported `ok` and left alone.
- Existing files or wrong symlinks are moved to
  `~/.dotfiles-backup-YYYYmmdd-HHMMSS/` before linking.
- Missing repo sources are skipped with `skip`.
- Verification checks every critical link points inside `$DOTFILES_DIR`.
- Stale-path checking currently scans `.config/i3`, `.config/polybar`,
  `.config/kitty`, and `.fehbg` for literal `/home/<user>/` paths.
- The Flameshot directory itself is not symlinked. Only the selected
  `flameshot.ini` is linked.

## 7. Packages

### Arch

Base packages:

| Group | Packages |
| --- | --- |
| Build and clone | `base-devel` `git` |
| Search and jump | `fzf` `zoxide` |
| Shell | `zsh` `zsh-autosuggestions` `zsh-syntax-highlighting` |
| Python and portals | `python-gobject` `python-pipx` |
| Window manager and session | `i3-wm` `i3blocks` `i3lock` `xss-lock` `ly` |
| Xorg | `xorg-server` `xorg-xinit` `xorg-xrandr` `xorg-xinput` `xorg-xrdb` |
| Desktop UI | `kitty` `dunst` `picom` `xsettingsd` `feh` `flameshot` `polybar` `rofi` |
| Brightness and notifications | `brightnessctl` `libnotify` |
| Network and hardware | `network-manager-applet` `power-profiles-daemon` `lm_sensors` `pavucontrol` |
| XDG | `xdg-desktop-portal` `xdg-desktop-portal-gtk` `xdg-utils` |
| Fonts | `otf-geist-mono-nerd` `inter-font` `ttf-jetbrains-mono-nerd` |
| Apps | `thunar` `opencode` `nano` `steam` |
| JavaScript | `nodejs` `npm` |
| Tools | `htop` `wget` `github-cli` `ufw` `bluez-utils` `smartmontools` `zram-generator` `efibootmgr` `tailscale` `syncthing` |

Laptop extras: `linux-zen-headers`.

AUR packages: `zen-browser-bin` `everforest-icon-theme-git` `gtk-engine-murrine`.

Laptop AUR extras: `tuxedo-drivers-dkms`.

Laptop vendor installs from source:

- `https://github.com/Rodsantos1337/fans-g5-kf` into `~/src/fans-g5-kf`
- `https://github.com/Rodsantos1337/kbl` into `~/src/kbl`
- Each repo's own `sudo ./install.sh` is run. `fans-guard` is enabled if present.

### Fedora

Base packages:

| Group | Packages |
| --- | --- |
| Build and clone | `gcc` `gcc-c++` `make` `kernel-devel` `git` `curl` `wget` |
| Search and jump | `fzf` `zoxide` |
| Shell | `zsh` `zsh-autosuggestions` `zsh-syntax-highlighting` |
| Search and LSP | `ripgrep` `fd-find` `clang-tools-extra` |
| Python | `python3-gobject` `pipx` |
| Window manager and session | `i3` `i3blocks` `i3lock` `xss-lock` |
| Xorg | `xorg-x11-server-Xorg` `xorg-x11-xinit` `xrandr` `xrdb` `xinput` |
| Desktop UI | `kitty` `dunst` `picom` `xsettingsd` `feh` `flameshot` `polybar` `rofi` |
| Brightness and notifications | `brightnessctl` `libnotify` |
| Theme engine | `gtk-murrine-engine` |
| Network and hardware | `network-manager-applet` `power-profiles-daemon` `lm_sensors` `pavucontrol` |
| XDG | `xdg-desktop-portal` `xdg-desktop-portal-gtk` `xdg-utils` |
| Fonts | `jetbrains-mono-fonts` `rsms-inter-fonts` `fontawesome4-fonts` |
| Apps | `Thunar` `nano` `qutebrowser` `steam` |
| Spell and gaming | `aspell` `aspell-en` `gamemode` |
| JavaScript | `nodejs22` `nodejs22-npm` |
| Tools | `htop` `wget` `gh` `ufw` `unzip` `bluez` `bluez-tools` `smartmontools` `zram-generator` `efibootmgr` `syncthing` `pnpm` |

Laptop extras: `thermald` `powertop` `acpi`.

Third-party dnf package: `zen-browser` from COPR `sneexy/zen-browser`.

### Shared third-party installs

| Tool | Method |
| --- | --- |
| Zen | COPR `sneexy/zen-browser` |
| Tailscale | `https://tailscale.com/install.sh` |
| opencode | `https://opencode.ai/install` |
| bun | `https://bun.sh/install` into `~/.bun` |
| ttt LSP servers | `npm install -g vscode-langservers-extracted` (html/css; markdown via marksman) |
| Nerd Fonts | Arch packages; Fedora GeistMono and JetBrainsMono zips to `/usr/local/share/fonts` |
| Everforest icons | Arch AUR; Fedora clone `ItzSelenux/everforest-icon-theme` into `~/.local/share/icons` |
| ttt | Official install script into `~/.local/bin` |
| marksman | Upstream release binary into `~/.local/bin` |
| llmserve | Clone `Rodsantos1337/llmserve` into `~/base/llmserve`, run its setup/install if present |
| opencode plugins | `npm install` in `~/.config/opencode` from tracked `package.json` |

Notes:

- Configs for `alacritty` and `neovim` are still linked, but the packages
  are not installed. `dnf install alacritty neovim` if you want them back.
- `vscode-html-language-server` is referenced by ttt LSP settings but is not
  installed by `setup.sh`. Install it separately for HTML LSP.
- `fresh` is expected by `fresh-vault-toggle` but is not installed by
  `setup.sh`. Install it into `~/.local/bin` or the scratchpad will notify and
  exit.

## 8. Services and system configuration

`setup.sh` enables or configures:

| Area | Action |
| --- | --- |
| Power | `power-profiles-daemon` enabled and started |
| Firewall | `ufw` enabled; tailnet allowed in on `tailscale0` |
| Tailscale | `tailscaled` enabled; `tailscale up` if not already joined |
| Syncthing | User unit `syncthing.service` enabled; lingering enabled for the user |
| Vault | Creates `~/vault` and `~/base/ACI/screenshots` |
| Shell | Sets login shell to `zsh` when installed |
| Keyboard | `localectl set-keymap pt-latin1`, `localectl set-x11-keymap pt` |
| GTK | Applies Everforest GTK theme, icons, dark color scheme, cursor size 14, flat mouse/touchpad |
| Display manager | Arch enables `ly@tty1` only if none is enabled. Fedora keeps the existing one or installs `lightdm` + `lightdm-gtk` |
| Laptop | Enables `thermald` |
| Firewall | Disables `firewalld` so ufw is the single firewall |

User units tracked under `.config/systemd/user`:

- `appimagelauncherd.service`
- `default.target.wants/appimagelauncherd.service` (symlink)
- `default.target.wants/syncthing.service` (symlink)

Shell power toggles in `.bashrc` and `.zshrc`:

| Function | Effect |
| --- | --- |
| `tails-on` | Start `tailscaled` and run `tailscale up` |
| `tails-off` | `tailscale down`, stop `tailscaled` |
| `sync-on` | Start user `syncthing.service` |
| `sync-off` | Stop user `syncthing.service` |
| `share-on` | Both Tailscale and Syncthing on |
| `share-off` | Both off |

## 9. Desktop UX

### i3

`$mod` is `Mod4` (Super). The PT layout uses `ccedilla` as the right-direction
key. On another layout, that binding may need to change.

Applications and session:

| Binding | Action |
| --- | --- |
| `$mod+Return` | kitty |
| `$mod+q` | kill focused window |
| `$mod+d` | rofi drun launcher |
| `$mod+Shift+e` | rofi power menu |
| `$mod+Shift+p` | power profile switcher |
| `$mod+w` | Zen browser |
| `$mod+n` | Thunar |
| `$mod+o` | ttt vault scratchpad |
| `$mod+Shift+o` | fresh vault scratchpad |
| `$mod+Shift+x` | toggle high refresh / 60Hz |
| `$mod+Shift+g` | gaming mode: hide polybar, stop picom |
| `Print` | Flameshot GUI |
| `$mod+Print` | Flameshot full |
| `$mod+Shift+Print` | Flameshot screen |
| `$mod+Shift+f` | fans max (Gigabyte G5 KF only) |
| `$mod+Control+f` | fans auto (Gigabyte G5 KF only) |
| `$mod+Mod1+f` | fan status |
| `$mod+b` | keyboard backlight toggle |

Window management:

| Binding | Action |
| --- | --- |
| `$mod+j` / `$mod+k` / `$mod+l` / `$mod+ccedilla` | focus left / down / up / right |
| `$mod+Left` / `Down` / `Up` / `Right` | focus left / down / up / right |
| `$mod+Shift+j` / `k` / `l` / `ccedilla` | move window left / down / up / right |
| `$mod+Shift+arrows` | move window in arrow direction |
| `$mod+h` | split horizontal |
| `$mod+v` | split vertical |
| `$mod+f` | fullscreen toggle |
| `$mod+s` | stacking layout |
| `$mod+g` | tabbed layout |
| `$mod+e` | toggle split layout |
| `$mod+Shift+space` | toggle floating |
| `$mod+space` | focus tiling/floating |
| `$mod+a` | focus parent |
| `$mod+r` | enter resize mode |
| `$mod+Shift+c` | reload i3 |
| `$mod+Shift+r` | restart i3 |

Workspaces:

| Binding | Action |
| --- | --- |
| `$mod+1` through `$mod+0` | switch to workspace 1 through 10 |
| `$mod+Shift+1` through `$mod+Shift+0` | move container to workspace 1 through 10 |

Resize mode: `j`, `k`, `l`, `ccedilla` and arrow keys resize. `Return`,
`Escape`, or `$mod+r` exits resize mode.

Media keys:

| Binding | Action |
| --- | --- |
| `XF86AudioRaiseVolume` / `LowerVolume` | pactl volume +/- 10% |
| `XF86AudioMute` | toggle sink mute |
| `XF86AudioMicMute` | toggle source mute |
| `XF86MonBrightnessUp` / `Down` | brightness script with dunst OSD |

Startup:

- `xss-lock` with `i3lock`
- `nm-applet`
- `dunst` with `~/.config/dunst/dunstrc`
- `picom` with `~/.config/picom/picom.conf`
- `polybar/launch.sh`
- `xsettingsd`
- `xrdb -merge ~/.Xresources`
- `feh --bg-fill ~/Pictures/new.jpg` after 1 second
- `disable-mouse-accel.sh`
- `setxkbmap -layout pt`
- `flameshot`
- per-machine `include ~/.config/i3/local*`

Scratchpads: `ttt-vault`, `fresh-vault`, and `ttt-float` are floating and sent
to the scratchpad. ttt-vault and fresh-vault are 1200x800 and centered.
ttt-float is 1000x700 and centered.

### i3 scripts

| Script | Role |
| --- | --- |
| `battery` | i3blocks battery block for `BAT0` with Font Awesome glyphs |
| `brightness` | brightnessctl plus in-place dunst progress notification |
| `fresh-vault-toggle` | toggle `fresh` in `~/vault` as `fresh-vault` scratchpad |
| `gaming-toggle` | hide polybar and stop picom; restore on second press |
| `obsidian-toggle2` | launch or show Obsidian in `~/vault` as scratchpad. Not bound in current config |
| `powermenu` | rofi power menu, including battery-save RAPL limits |
| `power-profiles` | rofi power profile switcher |
| `pp-indicator` | print current power profile for polybar |
| `refresh-toggle` | toggle DP-0 75Hz or eDP-1 144Hz against 60Hz |
| `ttt-toggle` | floating ttt scratchpad. Not bound in current config |
| `ttt-vault-toggle` | ttt vault scratchpad bound to `$mod+o` |
| `volume` | i3blocks volume block with click and scroll actions |

### Polybar

Bottom bar, 30px, Everforest palette. Left module is i3 workspaces, center is
date, right is CPU temperature, memory, disk, volume, power profile, battery,
and tray. Fonts are Inter 12 and GeistMono Nerd Font Mono 12.

`launch.sh` starts `main` with the tray on `DP-0` when present, otherwise on
the primary or first connected monitor. Every other monitor gets
`main-notray`. This avoids multiple systray owners.

### Rofi

`rofi -show drun` uses `drun,run`, icons, `Everforest-Dark` icon theme, Inter
12, and `everforest-dim.rasi`. Selected rows are green with dark text.

### Dunst

Bottom-right, follows the mouse, 300px wide, maximum 5 notifications,
JetBrainsMono Nerd Font Mono 10, progress bars enabled, Everforest colors.
Critical notifications use a red background and never expire.

### Picom

GLX backend, shadows, fading, 8px rounded corners, and stock picom v13
appear/disappear animations. No blur. `vsync` and `xrender-sync-fence` are
disabled for lower input latency. Rofi, Dunst, polybar, docks, and
notifications are excluded from shadows and rounding. Gaming mode stops picom
entirely.

### Flameshot

Active-monitor capture with X11 legacy screenshot mode. The save path is
machine-specific and selected by the install variant.

## 10. Theming system

The palette is documented in `everforest-green-dark-dim.md`. Core ramp:

| Role | Color |
| --- | --- |
| Main background | `#1e2326` |
| Inputs / base | `#232a2e` |
| Hover / WM buttons | `#2e383c` |
| Borders / separators | `#3a4141` |
| Terminal black | `#323c41` |
| Foreground | `#ffffff` |
| Green | `#a7c080` |
| Red | `#e67e80` |
| Yellow | `#dbbc7f` |
| Blue | `#7fbbb3` |
| Purple | `#d699b6` |
| Aqua | `#83c092` |
| Orange | `#e69875` |
| Muted grey | `#7a8478` |
| Secondary grey | `#859289` |

Where the palette is applied:

| Component | Source |
| --- | --- |
| i3 window borders | `.config/i3/config` color variables |
| GTK3 | `.config/gtk-3.0/settings.ini` |
| GTK4 | `.config/gtk-4.0/settings.ini` |
| X settings | `.config/xsettingsd/xsettingsd.conf` |
| GTK theme files | `themes/` (`Salvia-Dim` active) |
| Polybar | `.config/polybar/config.ini` |
| Rofi | `.config/rofi/salvia-dim.rasi` |
| Dunst | `.config/dunst/dunstrc` |
| Picom | `.config/picom/picom.conf` |
| Kitty | `.config/kitty/kitty.conf` |
| Alacritty | `.config/alacritty/alacritty.toml` |
| Qutebrowser | `.config/qutebrowser/config.py` |
| Neovim | `sainnhe/everforest` via LazyVim |
| Zed | `.config/zed/themes/Everforest Dark Dim.json` |
| ttt | `.config/ttt/themes/everforest-dim.json` |
| opencode | `.config/opencode/themes/salvia-dim.json` |
| Wallpaper | `wallpapers/new.jpg` linked to `~/Pictures/new.jpg` |

`apply_salvia_theming` also sets the GTK theme, icon theme, dark color
scheme, cursor size 14, and flat mouse/touchpad profiles through gsettings.

Cursor sizes are not fully unified in the working tree: `.Xresources` and
`.xprofile` use 24, GTK3 and xsettingsd use 14, and GTK4 uses 16. Adjust these
together when porting.

## 11. Application inventory

| App | Config | Notable behavior |
| --- | --- | --- |
| i3 | `.config/i3/config`, `monitors-*` | Mod4, gaps 8/4, no borders, per-machine monitors |
| Polybar | `.config/polybar/` | Bottom bar, tray on one monitor, power/battery/volume modules |
| Rofi | `.config/rofi/` | drun/run launcher and power menus |
| Dunst | `.config/dunst/dunstrc` | Follow mouse, in-place OSD progress, Everforest |
| Picom | `.config/picom/picom.conf` | Shadows, fading, rounding, animations, no blur |
| Kitty | `.config/kitty/kitty.conf` | GeistMono 10, tab bar, terminal-style tab shortcuts |
| Alacritty | `.config/alacritty/alacritty.toml` | GeistMono 10, matching colors |
| Qutebrowser | `.config/qutebrowser/config.py` | Vim keys, adblock, privacy, session autosave |
| Neovim | `.config/nvim/` | LazyVim, Everforest, clangd extra, lazy-lock pinned |
| Zed | `.config/zed/` | Everforest Dark Dim, telemetry off |
| ttt | `.config/ttt/` | Everforest, LSP, spell, tasks, JSON viewer, HTML LSP |
| opencode | `.config/opencode/` | Everforest theme, TUI status plugin, AGENTS.md style |
| Flameshot | `.config/flameshot/flameshot-<variant>.ini` | Active monitor, machine-specific save path |
| GTK / X11 | `.config/gtk-*`, `.config/xsettingsd`, `.Xresources` | Fonts, theme, cursor, LCD rendering |
| XDG | `.config/mimeapps.list`, `user-dirs.*` | Zen defaults, standard home directories |

### ttt details

Settings: theme `everforest-dim`, 4-space tabs, word wrap, line numbers, no
automatic bracket/quote closing, compact gutter, rounded borders, no menu bar.
LSP servers: HTML via `vscode-html-language-server --stdio`, Markdown via
`marksman server`. Autocomplete is enabled.

Keybindings include `alt+shift+m` and `alt+m` for menu bar, `ctrl+b` sidebar,
`ctrl+k b` panel, `ctrl+k ctrl+b` border cycle, `ctrl+k ctrl+g` gutter cycle,
`ctrl+k ctrl+l` line numbers, and `alt+left` / `alt+right` sidebar resize.

Registered plugins in `plugins.ttt.json`:

| Plugin | Source | Purpose |
| --- | --- | --- |
| `spell` | `eugenioenko/ttt-spell` | Spell check via `aspell` |
| `lsp-markdown` | local | Marksman Markdown LSP |
| `tasks` | local | Sidebar listing each project's `tasks/` folder |
| `json-viewer` | `eugenioenko/ttt-plugins` | Expandable JSON tree preview |
| `lsp-html` | `eugenioenko/ttt-plugins` | HTML language server |

The `ai-quick-edit` plugin directory exists but is not registered in the
working tree.

### opencode details

`opencode.jsonc` only declares the schema. `package.json` pins
`@opencode-ai/plugin` 1.18.30. The TUI theme is `salvia-dim`. The
TUI status plugin is loaded with an absolute `file:///home/rod-desktop/...`
path, so it must be changed on another machine.

## 12. Machine-specific state and exclusions

Variant selection:

- `setup.sh` and `install.sh` both require an explicit `--desktop` or
  `--laptop` flag. There is no hostname detection.

Monitor layouts:

| Variant | Layout |
| --- | --- |
| Desktop | `DP-0` primary 1920x1080@74.92, `HDMI-0` 1360x768@60.02 left of DP-0 |
| Laptop | `eDP-1` primary 1920x1080@144 |

Machine-specific paths:

| Item | Desktop | Laptop |
| --- | --- | --- |
| Flameshot save path | `/home/rod-desktop/base/ACI/screenshots` | `/home/rod/base/ACI/screenshots` |
| i3 monitor link | `monitors-desktop` | `monitors-laptop` |

Shared runtime paths created or assumed:

- `~/vault` for notes and scratchpad tools
- `~/base/ACI/screenshots` for Flameshot
- `~/base/llmserve` for llmserve
- `~/.local/bin` for ttt, marksman, and fresh
- `~/.local/share/themes/` (`Everforest-Green-Dark-Dim`, `Salvia-Dim`, `Salvia`)
- `~/.local/share/icons/Everforest-Dark`

Gitignored or untracked machine state:

| Path | Reason |
| --- | --- |
| `.config/ttt/state.json` | ttt runtime state |
| `.config/ttt/state/` | ttt plugin state |
| `.config/syncthing/` | device keys and per-machine config |
| `.quill/` | quill session notes |
| `node_modules/` | npm dependencies |
| `*.bak*`, `*.swp`, `*.tmp`, `*.DS_Store` | editor and backup junk |
| `__pycache__/`, `*.pyc` | Python bytecode |
| `log.log` | stray setup output |

No secrets are tracked. GitHub auth uses the `gh` credential helper. Tailscale
and Syncthing state stay outside the repo.

Hardcoded home paths to change when porting:

| File | Hardcoded value |
| --- | --- |
| `.fehbg` | `/home/rod-desktop/Pictures/new.jpg` |
| `.zshrc` | `/home/rod-desktop/.bun/_bun` |
| `.zshrc` | `/home/rod-desktop/.local/bin/task` |
| `.bashrc` | `/home/rod-desktop/.local/bin/task` |
| `.config/opencode/tui.json` | `file:///home/rod-desktop/.config/opencode/...` |
| `.config/opencode/tui.jsonc` | `file:///home/rod-desktop/.config/opencode/...` |
| `.config/gamemode.ini` | `/home/rod-desktop/.config/picom/picom.conf` |
| `.config/flameshot/flameshot-desktop.ini` | `/home/rod-desktop/base/ACI/screenshots` |
| `.config/flameshot/flameshot-laptop.ini` | `/home/rod/base/ACI/screenshots` |

The install-time stale-path check only covers `.config/i3`, `.config/polybar`,
`.config/kitty`, and `.fehbg`. It will not catch the other entries above.

## 13. Porting checklist

1. Clone the repo and pick the correct variant flag (`--desktop` / `--laptop`).
2. If forking, update the repo URL in `README.md` and `lib/dotfiles.sh`
   (`REPO_URL`).
3. Update the git identity in `lib/dotfiles.sh` and `.gitconfig`.
4. Always pass `--desktop` / `--laptop` to `setup.sh` and `install.sh`.
5. Edit `.config/i3/monitors-<variant>` for the target display layout.
6. Choose the wallpaper in `.config/i3/config` and regenerate `.fehbg`.
7. Update the Flameshot save path in both `flameshot-*.ini` files.
8. Replace hardcoded `/home/...` paths listed in section 12.
9. Change the keyboard layout in `lib/theming.sh`, `.xprofile`, and
   `.config/i3/config` if not using PT.
10. Adjust `~/vault`, `~/base/ACI/screenshots`, and
    `~/base/llmserve` assumptions if the target layout differs.
11. Install manually anything the package lists do not cover:
    `vscode-html-language-server`, `fresh`, and any other missing apps.
12. Run the auth steps: `gh auth login`, `opencode auth`, `sudo tailscale up`,
    and Syncthing pairing.
13. Run `setup.sh` or `install.sh` and confirm the verification output.
14. Log out and back in, then validate i3 with `i3 -C -c ~/.config/i3/config`.

## 14. Verification and troubleshooting

Installer verification:

```sh
~/dotfiles/install.sh --desktop
~/dotfiles/install.sh --laptop
```

Expected output includes `ok` for critical links and no `MISS` lines. A
non-zero stale-path result prints `STALE PATH` and the offending lines.

i3 config check:

```sh
i3 -C -c ~/.config/i3/config
```

Provisioning logs:

- Fedora dnf: `~/.cache/setup-fedora-dnf.log`

Fedora recovery scripts:

- `restore-desktop.sh`: run from a TTY after a package removal or missing X
  session. Reinstalls the display manager, Xorg, i3 stack, fonts, cursor, and
  printing, then re-enables graphical boot.
- `fix-boot-i3.sh`: run from a TTY to pin LightDM to the GTK greeter and i3,
  install the i3 wallpaper as the greeter background, and enable graphical boot.

Known inert or manual items:

- `/etc/ly/config.ini` brightness keys only affect the login screen. Day-to-day
  brightness is handled by i3 and `.config/i3/scripts/brightness`.
- Archinstall owns PipeWire, zram, kernel, GPU, firmware, and the initial
  display manager. Do not expect `setup.sh` to recreate those.
- The repo must be public before a fresh machine can clone it. If it was made
  private, change visibility back to public first.
- `obsidian-toggle2` and `ttt-toggle` exist but are not bound in the current i3
  config.
- `ttt.log` is currently untracked and not ignored. Add it to `.gitignore` or
  remove it if it should not appear in status.

## 15. Drift snapshot

This document describes the working tree, not only HEAD.

Base: `a7fedb2`.

Modified:

- `.bashrc`
- `.config/i3/config`
- `.config/kitty/kitty.conf`
- `.config/opencode/tui.json`
- `.config/ttt/plugins.ttt.json`
- `.config/ttt/settings.json`
- `.fehbg`
- `.zshrc`
- `README.md` (adds the pointer to this document)

Deleted from the working tree:

- `.config/ttt/plugins/markdown-preview/`
- `.config/ttt/plugins/ttt-ghost/`

Untracked:

- `.config/i3/scripts/fresh-vault-toggle`
- `.config/opencode/tui.jsonc`
- `.config/ttt/plugins/json-viewer/`
- `.config/ttt/plugins/lsp-html/`
- `.config/ttt/plugins/tasks/`
- `.config/ttt/ttt.log`
- `dotfiles.md` (new, this document)

Notable working-tree effects:

- i3 wallpaper is now `new.jpg` instead of `bg-newer.jpg`.
- `$mod+Shift+o` now opens `fresh` in `~/vault`. `$mod+Shift+t` and `$mod+x`
  ttt bindings were removed.
- Kitty gained tab bar styling and tab shortcuts.
- opencode TUI now loads the Orca status plugin from an absolute path.
- ttt now registers `tasks`, `json-viewer`, and `lsp-html`; the old
  `markdown-preview` and `ttt-ghost` plugins are gone from the working tree.
- Shell files gained a `task` alias pointing at
  `/home/rod-desktop/.local/bin/task`.

## 16. Appendix

External repositories referenced by provisioning:

| Repo | Purpose |
| --- | --- |
| `https://github.com/Rodsantos1337/dotfiles` | This repo |
| `https://github.com/Rodsantos1337/llmserve` | llmserve project |
| `https://github.com/Rodsantos1337/fans-g5-kf` | Gigabyte G5 KF fan control |
| `https://github.com/Rodsantos1337/kbl` | Keyboard backlight control |
| `https://github.com/eugenioenko/ttt` | ttt editor |
| `https://github.com/eugenioenko/ttt-plugins` | ttt JSON and HTML LSP plugins |
| `https://github.com/eugenioenko/ttt-spell` | ttt spell plugin |
| `https://github.com/ItzSelenux/everforest-icon-theme` | Everforest icons on Fedora |
| `https://github.com/artempyanykh/marksman` | Markdown LSP |
| `https://github.com/sainnhe/everforest` | Everforest palette source |

Source-of-truth files:

| Topic | File |
| --- | --- |
| Provisioning flow | `setup.sh` |
| Package lists | `lib/packages.sh` |
| Service behavior | `lib/services.sh` |
| External installs | `lib/browsers.sh`, `lib/dotfiles.sh` |
| Symlink contract | `install.sh` |
| i3 behavior | `.config/i3/config` |
| Palette rationale | `everforest-green-dark-dim.md`, `salvia-dim.md`, `salvia.md` |

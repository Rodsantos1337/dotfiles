#!/usr/bin/env bash
#
# setup.sh - provision a fresh Arch (archinstall i3) machine
#
# Installs every package rod's setup needs, builds yay for the few AUR
# packages, enables services, applies gsettings theming, clones the
# dotfiles and symlinks them into $HOME, dev-installs quill, then flips
# the dotfiles repo back to private.
#
# Usage: ./setup.sh   (run as your normal user; sudo is invoked where needed)
# Idempotent: pacman/yay use --needed; install.sh skips existing links.

set -euo pipefail

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "error: run as your normal user (sudo is invoked where needed)" >&2
  exit 1
fi

# --- 0. refresh pacman mirrors -----------------------------------------------
# A stale/dead first mirror (e.g. fastly.mirror.pkgbuild.com returning 404 on
# core.db) makes `pacman -Syu` fail hard under set -e. Instead of probing
# mirrors ourselves, pull a pre-filtered list from archlinux.org: with
# use_mirror_status=on the API only returns mirrors that are up and synced.
echo "== [0/9] refreshing pacman mirrors =="
MIRRORLIST=/etc/pacman.d/mirrorlist
NEW="$(mktemp)"
if curl -fsS --max-time 20 \
    "https://archlinux.org/mirrorlist/?protocol=https&use_mirror_status=on" \
    | sed -e 's/^#Server/Server/' -e '/^#/d' >"$NEW" &&
    [[ -s "$NEW" ]]; then
  # truncate after capture: piping curl into `head` causes a SIGPIPE
  # (exit 23) that pipefail would treat as a hard failure
  { echo "# refreshed by setup.sh $(date -Iseconds)"; head -10 "$NEW"; } |
    sudo tee "$MIRRORLIST" >/dev/null
  echo "mirrorlist refreshed ($(wc -l <"$NEW") healthy mirrors)"
else
  echo "warning: could not fetch fresh mirrorlist - keeping current one" >&2
fi
rm -f "$NEW"

# --- 0b. enable multilib (required for steam) ----------------------------------
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  echo "enabling [multilib] in /etc/pacman.conf"
  sudo sed -i '/^#\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/ s/^#\(\[multilib\]\|Include\)/\1/' /etc/pacman.conf
fi

# --- 1. pacman packages ----------------------------------------------------
# NOTE: python-gobject is listed as an *optional* dep of
# power-profiles-daemon but powerprofilesctl requires it
# (else: ModuleNotFoundError: gi.repository).
PACMAN_PKGS=(
  # build/clone toolchain (yay needs base-devel; git clones this repo)
  base-devel git
  # fuzzy finder; required by LazyVim's default fzf-lua picker
  # (+ Ctrl+R history, Ctrl+T files, Alt+C dirs via key-bindings.bash)
  fzf zoxide
  python-gobject python-pipx
  # session / window manager (ly = display manager/login screen)
  i3-wm i3blocks dmenu i3lock xss-lock ly
  xorg-server xorg-xinit xorg-xrandr xorg-xinput xorg-xrdb
  # system UI
  alacritty dunst picom xsettingsd feh flameshot polybar rofi
  # brightness OSD: i3 fn-keys -> scripts/brightness needs brightnessctl +
  # notify-send (libnotify); neither comes from archinstall's i3 profile
  brightnessctl libnotify
  # NOTE: gtk-engine-murrine moved to the AUR section below - it was
  # dropped from [extra]; one missing target aborts the whole transaction
  network-manager-applet power-profiles-daemon lm_sensors pavucontrol
  # portals/xdg: screen sharing, file dialogs, open-with handlers
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-utils
  # fonts - GeistMono Nerd Font Mono everywhere
  otf-geist-mono-nerd inter-font ttf-jetbrains-mono-nerd
  # apps
  thunar opencode nano neovim steam
  # JS runtime
  nodejs npm
  # tools
  htop wget github-cli ufw bluez-utils smartmontools zram-generator efibootmgr tailscale syncthing
)
echo "== [1/9] pacman packages =="
# full pacman output lands in this log so failures are always debuggable
PACMAN_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/setup-pacman.log"
{
  echo "=== setup.sh run $(date -Iseconds) ==="
  # refresh keyring first: stale ISO keyrings break signature checks mid-upgrade
  sudo pacman -Sy --needed archlinux-keyring
  sudo pacman -Su --needed "${PACMAN_PKGS[@]}"
} |& tee -a "$PACMAN_LOG"

# --- 2. yay (AUR helper) -----------------------------------------------------
# go is a makedepends of the yay PKGBUILD; makepkg -s pulls it automatically.
if ! command -v yay >/dev/null 2>&1; then
  echo "== [2/9] building yay =="
  rm -rf /tmp/yay
  git clone --depth 1 https://aur.archlinux.org/yay.git /tmp/yay
  (
    cd /tmp/yay
    makepkg -si
  )
fi

# --- 3. AUR packages ---------------------------------------------------------
echo "== [3/9] AUR packages =="
yay -S --needed zen-browser-bin vscodium-bin everforest-icon-theme-git gtk-engine-murrine

# --- 4. services ---------------------------------------------------------------
echo "== [4/9] services =="
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable --now ufw
# tailscale mesh + syncthing (vault sync to phone; pairing via web UI)
sudo systemctl enable --now tailscaled
sudo ufw allow in on tailscale0 comment 'tailnet'
systemctl --user enable --now syncthing.service
sudo loginctl enable-linger "$USER"   # syncthing syncs from boot, pre-login
mkdir -p "$HOME/vault"                # sync target (mod+o / mod+Shift+o)
echo "syncthing web UI: http://localhost:8384 (add phone, share ~/vault)"
# display manager: archinstall ships lightdm enabled; use ly only if nothing else
if ! systemctl is-enabled display-manager >/dev/null 2>&1; then
  sudo systemctl enable ly@tty1
fi

# --- 5. gsettings (dconf) ------------------------------------------------------
# The Everforest GTK theme alone is NOT enough: portal-aware apps
# (e.g. Firefox "System theme - auto") read color-scheme from gsettings
# and flip to light unless it is set here.
echo "== [5/9] gsettings =="
gsettings set org.gnome.desktop.interface icon-theme 'Everforest-Dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Everforest-Green-Dark-Dim'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-size 14
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.touchpad accel-profile 'flat'

# --- 5b. keyboard: pt-pt everywhere (TTY + X11/login + session fallback) -----
echo "== [5b/9] keyboard (pt) =="
sudo localectl set-keymap pt-latin1
sudo localectl set-x11-keymap pt
# session fallback lives in .xprofile + i3 config (setxkbmap -layout pt)

# --- 6. git identity + gh auth ----------------------------------------------
echo "== [6/9] git identity + gh auth =="
git config --global user.name  "Rodsantos1337"
git config --global user.email "108137142+Rodsantos1337@users.noreply.github.com"
# interactive fallback: opens the browser; skipped if already authed
if ! gh auth status >/dev/null 2>&1; then
  echo "gh: not authenticated - starting browser login"
  gh auth login -w -p https -h github.com
fi
# tailscale: interactive browser login, skipped if already joined
if ! sudo tailscale status >/dev/null 2>&1; then
  echo "tailscale: not authenticated - starting browser login"
  sudo tailscale up
fi

# --- 7. dotfiles -----------------------------------------------------------------
REPO_URL="https://github.com/Rodsantos1337/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
echo "== [7/9] dotfiles =="
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  git -C "$DOTFILES_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi
"$DOTFILES_DIR/install.sh"

# --- 8. quill (dev install, editable) -----------------------------------------
# quill is a private repo: requires gh auth from step 6. Non-fatal so a
# failed clone/install never blocks the privatize step below.
echo "== [8/9] quill dev install =="
QUILL_DIR="$HOME/base/quill"
if [[ ! -d "$QUILL_DIR/.git" ]]; then
  mkdir -p "$(dirname "$QUILL_DIR")"
  if ! git clone https://github.com/Rodsantos1337/quill.git "$QUILL_DIR"; then
    echo "warning: quill clone failed (private repo? gh authed?) - skipping" >&2
  fi
fi
if [[ -d "$QUILL_DIR/.git" ]] && ! pipx list | grep -q '^quill'; then
  pipx install -e "$QUILL_DIR"
fi

# --- 9. re-privatize dotfiles repo ---------------------------------------------
# The repo was made public pre-install so it could be cloned without auth.
# Only flip back on full success: a failed run leaves it public/inspectable.
echo "== [9/9] privatize dotfiles repo =="
if ! gh auth status >/dev/null 2>&1; then
  echo "warning: gh not authenticated - leaving repo visibility as-is" >&2
else
  VIS="$(gh repo view Rodsantos1337/dotfiles --json visibility -q .visibility)"
  if [[ "$VIS" == "PUBLIC" ]]; then
    gh repo edit Rodsantos1337/dotfiles --visibility private \
      --accept-visibility-change-consequences
  else
    echo "already $VIS, skipping"
  fi
fi

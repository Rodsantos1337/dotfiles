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

# --- 1. pacman packages ----------------------------------------------------
# NOTE: python-gobject is listed as an *optional* dep of
# power-profiles-daemon but powerprofilesctl requires it
# (else: ModuleNotFoundError: gi.repository).
PACMAN_PKGS=(
  # build/clone toolchain (yay needs base-devel; git clones this repo)
  base-devel git
  python-gobject python-pipx
  # session / window manager (ly = display manager/login screen)
  i3-wm i3blocks dmenu i3lock xss-lock ly
  xorg-server xorg-xinit xorg-xrandr xorg-xinput xorg-xrdb
  # system UI
  alacritty dunst picom xsettingsd feh flameshot
  # gtk2 theming engine (custom Everforest-Green-Dark-Dim gtk-2.0 needs it)
  gtk-engine-murrine
  network-manager-applet power-profiles-daemon lm_sensors pavucontrol
  # portals/xdg: screen sharing, file dialogs, open-with handlers
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-utils
  # fonts - GeistMono Nerd Font Mono everywhere
  otf-geist-mono-nerd inter-font
  # apps
  firefox thunar obsidian zed opencode nano
  # JS runtime
  nodejs npm
  # tools
  htop wget github-cli ufw bluez-utils smartmontools zram-generator efibootmgr
)
echo "== [1/9] pacman packages =="
sudo pacman -Syu --needed "${PACMAN_PKGS[@]}"

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
yay -S --needed brave-bin everforest-icon-theme-git

# --- 4. services ---------------------------------------------------------------
echo "== [4/9] services =="
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable --now ufw
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

# --- 6. git identity + gh auth ----------------------------------------------
echo "== [6/9] git identity + gh auth =="
git config --global user.name  "Rodsantos1337"
git config --global user.email "108137142+Rodsantos1337@users.noreply.github.com"
# interactive fallback: opens the browser; skipped if already authed
if ! gh auth status >/dev/null 2>&1; then
  echo "gh: not authenticated - starting browser login"
  gh auth login -w -p https -h github.com
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
echo "== [8/9] quill dev install =="
QUILL_DIR="$HOME/base/quill"
if [[ ! -d "$QUILL_DIR/.git" ]]; then
  mkdir -p "$(dirname "$QUILL_DIR")"
  git clone https://github.com/Rodsantos1337/quill.git "$QUILL_DIR"
fi
if ! pipx list | grep -q '^quill'; then
  pipx install -e "$QUILL_DIR"
fi

# --- 9. re-privatize dotfiles repo ---------------------------------------------
# The repo was made public pre-install so it could be cloned without auth.
# Only flip back on full success: a failed run leaves it public/inspectable.
echo "== [9/9] privatize dotfiles repo =="
VIS="$(gh repo view Rodsantos1337/dotfiles --json visibility -q .visibility)"
if [[ "$VIS" == "PUBLIC" ]]; then
  gh repo edit Rodsantos1337/dotfiles --visibility private \
    --accept-visibility-change-consequences
else
  echo "already $VIS, skipping"
fi

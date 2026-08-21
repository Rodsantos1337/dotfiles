#!/usr/bin/env bash
#
# setup.sh - provision a fresh Arch (archinstall i3) machine
#
# Installs every package rod's setup needs, builds yay for the few AUR
# packages, enables services, applies gsettings theming, then clones the
# dotfiles and symlinks them into $HOME.
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
  python-gobject
  # session / window manager (ly = display manager/login screen)
  i3-wm i3blocks dmenu i3lock xss-lock ly
  xorg-server xorg-xinit xorg-xrandr xorg-xinput xorg-xrdb
  # system UI
  alacritty dunst picom xsettingsd feh flameshot
  network-manager-applet power-profiles-daemon lm_sensors pavucontrol
  # fonts - CommitMono Nerd Font Mono everywhere
  otf-commit-mono-nerd inter-font
  # apps
  firefox thunar obsidian zed opencode nano
  # JS runtime
  nodejs npm
  # tools
  htop wget github-cli ufw bluez-utils smartmontools zram-generator efibootmgr
)
echo "== [1/6] pacman packages =="
sudo pacman -Syu --needed "${PACMAN_PKGS[@]}"

# --- 2. yay (AUR helper) -----------------------------------------------------
# go is a makedepends of the yay PKGBUILD; makepkg -s pulls it automatically.
if ! command -v yay >/dev/null 2>&1; then
  echo "== [2/6] building yay =="
  rm -rf /tmp/yay
  git clone --depth 1 https://aur.archlinux.org/yay.git /tmp/yay
  (
    cd /tmp/yay
    makepkg -si
  )
fi

# --- 3. AUR packages ---------------------------------------------------------
echo "== [3/6] AUR packages =="
yay -S --needed brave-bin everforest-gtk-theme-git everforest-icon-theme-git

# --- 4. services ---------------------------------------------------------------
echo "== [4/6] services =="
sudo systemctl enable --now power-profiles-daemon

# --- 5. gsettings (dconf) ------------------------------------------------------
# The Everforest GTK theme alone is NOT enough: portal-aware apps
# (e.g. Firefox "System theme - auto") read color-scheme from gsettings
# and flip to light unless it is set here.
echo "== [5/6] gsettings =="
gsettings set org.gnome.desktop.interface gtk-theme 'Everforest-Green-Dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-size 14
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.touchpad accel-profile 'flat'

# --- 6. dotfiles -----------------------------------------------------------------
REPO_URL="https://github.com/Rodsantos1337/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
echo "== [6/6] dotfiles =="
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  git -C "$DOTFILES_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi
exec "$DOTFILES_DIR/install.sh"

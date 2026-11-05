#!/usr/bin/env bash
#
# lib/packages.sh - Package lists per machine variant (Fedora)
# Source after common.sh

# Base packages for all variants
BASE_PKGS=(
  # build/clone toolchain
  gcc gcc-c++ make kernel-devel git curl wget
  fzf zoxide
  # shell
  zsh zsh-autosuggestions zsh-syntax-highlighting
  # search / LSP
  ripgrep fd-find clang-tools-extra
  python3-gobject pipx
  # session / window manager
  i3 i3blocks i3lock xss-lock
  xorg-x11-server-Xorg xorg-x11-xinit xrandr xrdb xinput
  # system UI
  kitty dunst picom xsettingsd feh flameshot polybar rofi
  brightnessctl libnotify
  gtk-murrine-engine
  network-manager-applet power-profiles-daemon lm_sensors pavucontrol
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-utils
  # fonts (Nerd Fonts installed separately via zip)
  jetbrains-mono-fonts rsms-inter-fonts fontawesome4-fonts
  # apps
  Thunar nano qutebrowser steam
  # spell check / gaming helpers
  aspell aspell-en gamemode
  # JS runtime
  nodejs22 nodejs22-npm
  # tools
  htop wget gh ufw unzip bluez bluez-tools smartmontools zram-generator efibootmgr syncthing pnpm
)

# Laptop-specific packages
LAPTOP_PKGS=(
  thermald powertop acpi
)

# Third-party apps installed via dnf (after repo setup)
THIRD_PARTY_PKGS=(
  zen-browser
)

# Get dnf packages for variant (desktop|laptop)
get_pkgs() {
  local variant="$1"
  local pkgs=("${BASE_PKGS[@]}")
  if [[ "$variant" == "laptop" ]]; then
    pkgs+=("${LAPTOP_PKGS[@]}")
  fi
  echo "${pkgs[@]}"
}

# Get third-party dnf packages
get_third_party_pkgs() {
  echo "${THIRD_PARTY_PKGS[@]}"
}

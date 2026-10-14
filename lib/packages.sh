#!/usr/bin/env bash
#
# lib/packages.sh - Package lists per distro and variant
# Source after common.sh

# =============================================================================
# ARCH PACKAGES
# =============================================================================

# Base packages for all Arch variants
ARCH_BASE_PKGS=(
  # build/clone toolchain
  base-devel git
  # fuzzy finder + jumper
  fzf zoxide
  # shell
  zsh zsh-autosuggestions zsh-syntax-highlighting
  python-gobject python-pipx
  # session / window manager
  i3-wm i3blocks i3lock xss-lock ly
  xorg-server xorg-xinit xorg-xrandr xorg-xinput xorg-xrdb
  # system UI
  kitty dunst picom xsettingsd feh flameshot polybar rofi
  # brightness OSD
  brightnessctl libnotify
  network-manager-applet power-profiles-daemon lm_sensors pavucontrol
  # portals/xdg
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-utils
  # fonts
  otf-geist-mono-nerd inter-font ttf-jetbrains-mono-nerd
  # apps
  thunar opencode nano neovim steam
  # JS runtime
  nodejs npm
  # tools
  htop wget github-cli ufw bluez-utils smartmontools zram-generator efibootmgr tailscale syncthing
)

# Laptop-specific Arch packages (Gigabyte G5 KF)
ARCH_LAPTOP_PKGS=(
  linux-zen-headers
)

# AUR packages for all Arch variants
ARCH_AUR_PKGS=(
  zen-browser-bin
  everforest-icon-theme-git
  gtk-engine-murrine
)

# Laptop-specific AUR packages
ARCH_LAPTOP_AUR_PKGS=(
  tuxedo-drivers-dkms
)

# =============================================================================
# FEDORA PACKAGES
# =============================================================================

# Base packages for all Fedora variants
FEDORA_BASE_PKGS=(
  # build/clone toolchain
  gcc gcc-c++ make kernel-devel git curl wget
  fzf zoxide
  # shell
  zsh zsh-autosuggestions zsh-syntax-highlighting
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
  Thunar nano neovim steam
  qutebrowser
  # JS runtime
  nodejs22 nodejs22-npm
  # tools
  htop wget gh ufw unzip bluez bluez-tools smartmontools zram-generator efibootmgr syncthing
)

# Laptop-specific Fedora packages
FEDORA_LAPTOP_PKGS=(
  thermald powertop acpi
)

# Third-party apps installed via dnf (after repo setup)
FEDORA_THIRD_PARTY_PKGS=(
  zen-browser
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Get pacman packages for variant
get_arch_pkgs() {
  local variant="$1"
  local pkgs=("${ARCH_BASE_PKGS[@]}")
  if [[ "$variant" == "laptop" ]]; then
    pkgs+=("${ARCH_LAPTOP_PKGS[@]}")
  fi
  echo "${pkgs[@]}"
}

# Get AUR packages for variant
get_arch_aur_pkgs() {
  local variant="$1"
  local pkgs=("${ARCH_AUR_PKGS[@]}")
  if [[ "$variant" == "laptop" ]]; then
    pkgs+=("${ARCH_LAPTOP_AUR_PKGS[@]}")
  fi
  echo "${pkgs[@]}"
}

# Get dnf packages for variant
get_fedora_pkgs() {
  local variant="$1"
  local pkgs=("${FEDORA_BASE_PKGS[@]}")
  if [[ "$variant" == "laptop" ]]; then
    pkgs+=("${FEDORA_LAPTOP_PKGS[@]}")
  fi
  echo "${pkgs[@]}"
}

# Get third-party dnf packages
get_fedora_third_party_pkgs() {
  echo "${FEDORA_THIRD_PARTY_PKGS[@]}"
}
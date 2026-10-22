#!/usr/bin/env bash
#
# setup.sh - Unified provisioning for Arch/Fedora desktop/laptop
#
# Usage: ./setup.sh [OPTIONS]
#   --arch              Target Arch Linux (auto-detected if omitted)
#   --fedora            Target Fedora (auto-detected if omitted)
#   --desktop           Desktop variant (auto-detected via hostname if omitted)
#   --laptop            Laptop variant (auto-detected via hostname if omitted)
#   --browser=NAME      Browser to install: zen (default: zen)
#   --no-quill          Skip quill dev install
#   --privatize         Flip dotfiles repo back to private on success
#   --no-privatize      Keep dotfiles repo public (default)
#   --no-verify         Skip dotfile link verification
#   -h, --help          Show this help
#
# Auto-detection:
#   Distro: /etc/os-release (Arch or Fedora)
#   Variant: hostname 'fedora*' = desktop, else laptop
#
# Examples:
#   ./setup.sh                          # Auto-detect everything
#   ./setup.sh --arch --laptop          # Force Arch laptop
#   ./setup.sh --fedora --desktop --browser=zen
#   ./setup.sh --no-quill --no-privatize

set -euo pipefail

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
DISTRO=""
VARIANT=""
BROWSER="zen"
PRIVATIZE=false
VERIFY=true
INSTALL_QUILL=true

for arg in "$@"; do
  case "$arg" in
    --arch)     DISTRO="arch" ;;
    --fedora)   DISTRO="fedora" ;;
    --desktop)  VARIANT="desktop" ;;
    --laptop)   VARIANT="laptop" ;;
    --browser=*) BROWSER="${arg#*=}" ;;
    --privatize) PRIVATIZE=true ;;
    --no-privatize) PRIVATIZE=false ;;
    --no-verify) VERIFY=false ;;
    --no-quill) INSTALL_QUILL=false ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Validate browser choice (zen-only; helium/codium removed)
if [[ "$BROWSER" != "zen" ]]; then
  echo "Invalid browser: $BROWSER (only zen is supported)" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Source libraries
# -----------------------------------------------------------------------------
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/packages.sh"
source "$LIB_DIR/services.sh"
source "$LIB_DIR/browsers.sh"
source "$LIB_DIR/dotfiles.sh"
source "$LIB_DIR/theming.sh"

# -----------------------------------------------------------------------------
# Distro-specific setup functions
# -----------------------------------------------------------------------------
setup_arch() {
  log_step "[arch] refreshing pacman mirrors"
  local mirrorlist="/etc/pacman.d/mirrorlist"
  local new_list
  new_list="$(mktemp)"
  if curl -fsS --max-time 20 "https://archlinux.org/mirrorlist/?protocol=https&use_mirror_status=on" \
    | sed -e 's/^#Server/Server/' -e '/^#/d' >"$new_list" && [[ -s "$new_list" ]]; then
    { echo "# refreshed by setup.sh $(date -Iseconds)"; head -10 "$new_list"; } | sudo tee "$mirrorlist" >/dev/null
    log_ok "mirrorlist refreshed ($(wc -l <"$new_list") healthy mirrors)"
  else
    log_warn "could not fetch fresh mirrorlist - keeping current one"
  fi
  rm -f "$new_list"

  # Enable multilib
  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    log_info "enabling [multilib] in /etc/pacman.conf"
    sudo sed -i '/^#\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/ s/^#\(\[multilib\]\|Include\)/\1/' /etc/pacman.conf
  fi

  log_step "[arch] installing pacman packages"
  local pacman_log="${XDG_CACHE_HOME:-$HOME/.cache}/setup-pacman.log"
  mkdir -p "$(dirname "$pacman_log")"
  {
    echo "=== setup.sh arch run $(date -Iseconds) ==="
    sudo pacman -Sy --needed archlinux-keyring
    local pkgs=($(get_arch_pkgs "$VARIANT"))
    sudo pacman -Su --needed "${pkgs[@]}"
  } |& tee -a "$pacman_log"

  # Build yay if needed
  if ! has_cmd yay; then
    log_step "[arch] building yay"
    rm -rf /tmp/yay
    git clone --depth 1 https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si)
  fi

  # AUR packages (zen-browser-bin is in ARCH_AUR_PKGS)
  log_step "[arch] installing AUR packages"
  local aur_pkgs=($(get_arch_aur_pkgs "$VARIANT"))
  yay -S --needed "${aur_pkgs[@]}"

  # Laptop-specific: fan control + keyboard backlight
  if [[ "$VARIANT" == "laptop" ]]; then
    log_step "[arch laptop] fan control + keyboard backlight"
    for repo in fans-g5-kf kbl; do
      local src_dir="$HOME/src/$repo"
      if [[ -d "$src_dir/.git" ]]; then
        git -C "$src_dir" pull --ff-only
      else
        mkdir -p "$(dirname "$src_dir")"
        git clone "https://github.com/Rodsantos1337/$repo.git" "$src_dir"
      fi
      sudo bash -c "cd \"$src_dir\" && exec ./install.sh"
    done
    # fans-guard will be enabled by enable_laptop_services
  fi
}

setup_fedora() {
  log_step "[fedora] system upgrade"
  sudo dnf upgrade --refresh -y

  log_step "[fedora] configuring third-party repos"
  local fedora_ver
  fedora_ver="$(rpm -E %fedora)"
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm" \
    || log_warn "rpmfusion install failed (already enabled?)"
  sudo dnf install -y dnf-plugins-core curl wget

  # Browser COPR (zen-only)
  if ! sudo dnf copr list --enabled 2>/dev/null | grep -q 'sneexy/zen-browser'; then
    sudo dnf copr enable -y sneexy/zen-browser
  fi

  log_step "[fedora] installing dnf packages"
  local dnf_log="${XDG_CACHE_HOME:-$HOME/.cache}/setup-fedora-dnf.log"
  mkdir -p "$(dirname "$dnf_log")"
  {
    echo "=== setup.sh fedora run $(date -Iseconds) ==="
    local pkgs=($(get_fedora_pkgs "$VARIANT"))
    sudo dnf install -y "${pkgs[@]}"
  } |& tee -a "$dnf_log"

  # Git identity + gh auth early (for later clones)
  setup_git_identity
  auth_gh

  # Third-party apps
  install_fedora_browsers
  install_tailscale_fedora
  install_opencode_fedora
  install_nerd_fonts_fedora
  install_everforest_icons_fedora

  # Laptop services (thermald) - enabled later in common steps
}

# -----------------------------------------------------------------------------
# Auto-detection
# -----------------------------------------------------------------------------
require_user

if [[ -z "$DISTRO" ]]; then
  DISTRO=$(detect_distro)
  log_info "auto-detected distro: $DISTRO"
fi

if [[ -z "$VARIANT" ]]; then
  VARIANT=$(detect_variant)
  log_info "auto-detected variant: $VARIANT (hostname: $(hostname))"
fi

log_step "starting setup for $DISTRO / $VARIANT (browser: $BROWSER)"

# -----------------------------------------------------------------------------
# Distro-specific setup
# -----------------------------------------------------------------------------
case "$DISTRO" in
  arch)
    setup_arch
    ;;
  fedora)
    setup_fedora
    ;;
  *)
    log_err "unsupported distro: $DISTRO"
    exit 1
    ;;
esac

# -----------------------------------------------------------------------------
# Common steps (both distros)
# -----------------------------------------------------------------------------
setup_git_identity
auth_gh
if [[ "$INSTALL_QUILL" == true ]]; then
  install_quillcode
fi
install_ttt
install_marksman
install_llmserve
auth_tailscale

sync_dotfiles
run_install_sh "$VARIANT"
install_opencode_deps

if [[ "$VERIFY" == true ]]; then
  verify_dotfile_links "$DOTFILES_DIR"
  check_stale_home_paths
fi

apply_everforest_theming
setup_keyboard_pt
setup_default_shell

enable_common_services
enable_display_manager "$DISTRO"
enable_laptop_services "$DISTRO"
disable_firewalld_if_fedora "$DISTRO"

if [[ "$PRIVATIZE" == true ]]; then
  privatize_dotfiles
fi

log_step "setup complete"
log_info "Log out/in (or \$mod+Shift+r in i3) to apply all changes"
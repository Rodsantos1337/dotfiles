#!/usr/bin/env bash
#
# setup.sh - Fedora provisioning for desktop/laptop
#
# Usage: ./setup.sh --desktop|--laptop [OPTIONS]
#   --desktop           Desktop variant (i3 monitors-desktop, flameshot-desktop)
#   --laptop            Laptop variant (i3 monitors-laptop, flameshot-laptop,
#                       thermald + powertop + acpi)
#   --privatize         Flip dotfiles repo back to private on success
#   --no-privatize      Keep dotfiles repo public (default)
#   --no-verify         Skip dotfile link verification
#   -h, --help          Show this help
#
# The variant flag is required - there is no auto-detection.
# Installs the Zen browser, links dotfiles via install.sh, applies the
# Salvia-Dim GTK theme, and enables services. Idempotent; safe to re-run.
#
# Examples:
#   ./setup.sh --laptop
#   ./setup.sh --desktop --privatize

set -euo pipefail

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
VARIANT=""
PRIVATIZE=false
VERIFY=true

for arg in "$@"; do
  case "$arg" in
    --desktop)  VARIANT="desktop" ;;
    --laptop)   VARIANT="laptop" ;;
    --privatize) PRIVATIZE=true ;;
    --no-privatize) PRIVATIZE=false ;;
    --no-verify) VERIFY=false ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VARIANT" ]]; then
  echo "Missing required flag: --desktop or --laptop" >&2
  exit 1
fi

if ! grep -qi '^ID=fedora' /etc/os-release 2>/dev/null; then
  echo "This script is for Fedora only." >&2
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
# System provisioning
# -----------------------------------------------------------------------------
setup_system() {
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

  # Zen browser COPR
  if ! sudo dnf copr list --enabled 2>/dev/null | grep -q 'sneexy/zen-browser'; then
    sudo dnf copr enable -y sneexy/zen-browser
  fi

  log_step "[fedora] installing dnf packages ($VARIANT)"
  local dnf_log="${XDG_CACHE_HOME:-$HOME/.cache}/setup-fedora-dnf.log"
  mkdir -p "$(dirname "$dnf_log")"
  {
    echo "=== setup.sh fedora/$VARIANT run $(date -Iseconds) ==="
    local pkgs=($(get_pkgs "$VARIANT"))
    sudo dnf install -y "${pkgs[@]}"
  } |& tee -a "$dnf_log"

  # Git identity + gh auth early (for later clones)
  setup_git_identity
  auth_gh

  # Third-party apps
  install_browsers
  install_tailscale
  install_opencode
  install_nerd_fonts
  install_everforest_icons
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
require_user

log_step "starting Fedora setup ($VARIANT)"

setup_system

# -----------------------------------------------------------------------------
# Common steps
# -----------------------------------------------------------------------------
setup_git_identity
auth_gh
install_ttt  install_marksman
  install_bun
  install_ttt_lsp_servers
  install_llmserve
auth_tailscale

sync_dotfiles
run_install_sh "$VARIANT"
install_opencode_deps

if [[ "$VERIFY" == true ]]; then
  verify_dotfile_links "$DOTFILES_DIR"
  check_stale_home_paths
fi

apply_salvia_theming
setup_xfce_terminal
setup_keyboard_pt
setup_default_shell

enable_common_services
enable_display_manager
enable_laptop_services "$VARIANT"

if [[ "$PRIVATIZE" == true ]]; then
  privatize_dotfiles
fi

log_step "setup complete"
log_info "Log out/in (or \$mod+Shift+r in i3) to apply all changes"

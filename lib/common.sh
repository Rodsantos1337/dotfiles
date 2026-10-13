#!/usr/bin/env bash
#
# lib/common.sh - Shared helpers for setup scripts
#
# Source this in other lib scripts: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_step() { echo -e "${BLUE}== $* ==${NC}"; }
log_ok()   { echo -e "${GREEN}ok:${NC} $*"; }
log_warn() { echo -e "${YELLOW}warn:${NC} $*" >&2; }
log_err()  { echo -e "${RED}err:${NC} $*" >&2; }
log_info() { echo -e "  $*"; }

# Require running as non-root (sudo invoked where needed)
require_user() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    log_err "run as your normal user (sudo is invoked where needed)"
    exit 1
  fi
}

# Detect distribution
detect_distro() {
  if [[ -f /etc/arch-release ]]; then
    echo "arch"
  elif [[ -f /etc/fedora-release ]]; then
    echo "fedora"
  else
    log_err "Unsupported distribution (only Arch and Fedora)"
    exit 1
  fi
}

# Detect machine variant (desktop/laptop) via hostname heuristic
# Fedora hostname = desktop, else laptop (matches install.sh)
detect_variant() {
  local hostname
  hostname="$(hostname)"
  if [[ "$hostname" == fedora* ]]; then
    echo "desktop"
  else
    echo "laptop"
  fi
}

# Check if command exists
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Run command with logging, capture output to log file
run_logged() {
  local log_file="$1"; shift
  echo "=== $(date -Iseconds) $* ===" >>"$log_file"
  "$@" 2>&1 | tee -a "$log_file"
}

# Idempotent git clone/pull
git_sync() {
  local repo_url="$1" dest_dir="$2"
  if [[ -d "$dest_dir/.git" ]]; then
    log_info "Updating $dest_dir"
    git -C "$dest_dir" pull --ff-only
  else
    log_info "Cloning $repo_url -> $dest_dir"
    git clone "$repo_url" "$dest_dir"
  fi
}

# Idempotent systemctl enable --now (system)
sysctl_enable_now() {
  local unit="$1"
  if ! systemctl is-enabled "$unit" >/dev/null 2>&1; then
    sudo systemctl enable --now "$unit"
  elif ! systemctl is-active "$unit" >/dev/null 2>&1; then
    sudo systemctl start "$unit"
  fi
}

# Idempotent systemctl enable --now (user)
sysctl_user_enable_now() {
  local unit="$1"
  if ! systemctl --user is-enabled "$unit" >/dev/null 2>&1; then
    systemctl --user enable --now "$unit"
  elif ! systemctl --user is-active "$unit" >/dev/null 2>&1; then
    systemctl --user start "$unit"
  fi
}

# Backup and symlink (idempotent)
link_config() {
  local src="$1" dest="$2" backup_dir="$3"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    log_ok "$dest (already linked)"
    return 0
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$backup_dir/$(dirname "$dest")"
    mv "$dest" "$backup_dir/$dest"
    log_info "backed up $dest -> $backup_dir/$dest"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  log_ok "linked $dest"
}

# Verify symlink points to dotfiles repo
verify_link() {
  local dest="$1" dotfiles_dir="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$dotfiles_dir/"* ]]; then
    log_ok "$dest -> $(readlink "$dest")"
    return 0
  else
    log_warn "$dest (not linked to \$DOTFILES_DIR)"
    return 1
  fi
}

# Check for stale literal /home/<user>/ paths in configs
check_stale_paths() {
  local dirs=("$@")
  local found=0
  for dir in "${dirs[@]}"; do
    while IFS= read -r -d '' file; do
      if grep -qE "/home/[A-Za-z0-9._-]+/" "$file"; then
        log_warn "STALE PATH in $file:"
        grep -nE "/home/[A-Za-z0-9._-]+/" "$file" >&2
        found=1
      fi
    done < <(find "$dir" -type f \( -name "*.conf" -o -name "config" -o -name ".fehbg" -o -name "*.sh" -o -name "*.ini" \) -print0 2>/dev/null)
  done
  return $found
}
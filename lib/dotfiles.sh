#!/usr/bin/env bash
#
# lib/dotfiles.sh - Dotfiles clone, install, and verification
# Source after common.sh

readonly REPO_URL="https://github.com/Rodsantos1337/dotfiles.git"
readonly DOTFILES_DIR="$HOME/dotfiles"

# Clone or update dotfiles repo
sync_dotfiles() {
  log_step "syncing dotfiles"
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    git -C "$DOTFILES_DIR" pull --ff-only
  else
    git clone "$REPO_URL" "$DOTFILES_DIR"
  fi
}

# Run install.sh with variant
run_install_sh() {
  local variant="$1"
  log_step "running install.sh (variant: $variant)"
  "$DOTFILES_DIR/install.sh" "--$variant"
}

# Verify critical symlinks point to dotfiles repo
verify_dotfile_links() {
  local dotfiles_dir="$1"
  local verify_rels=(
    ".bashrc" ".xprofile" ".Xresources" ".fehbg"
    "Pictures/bg.jpg" "Pictures/bg-old.jpg" "Pictures/new.jpg"
    ".config/i3/config" ".config/i3/scripts"
    ".config/alacritty" ".config/dunst" ".config/flameshot/flameshot.ini"
    ".config/fontconfig" ".config/gtk-3.0/settings.ini" ".config/gtk-4.0/settings.ini"
    ".config/opencode/themes" ".config/opencode/tui.json"
    ".config/picom" ".config/polybar" ".config/rofi" ".config/nvim"
    ".config/VSCodium" ".vscode-oss/argv.json" ".config/xsettingsd"
    ".config/disable-mouse-accel.sh"
    ".local/share/themes/Everforest-Green-Dark-Dim"
    ".config/quickshell"
  )

  local fail=0
  for rel in "${verify_rels[@]}"; do
    local dest="$HOME/$rel"
    if verify_link "$dest" "$dotfiles_dir"; then
      : # ok
    else
      fail=1
    fi
  done

  if [[ $fail -ne 0 ]]; then
    log_warn "some configs are not linked - re-run $dotfiles_dir/install.sh"
    return 1
  fi
  return 0
}

# Check for stale literal /home/<user>/ paths in deployed configs
check_stale_home_paths() {
  local dirs=(
    "$HOME/.config/i3"
    "$HOME/.config/polybar"
    "$HOME/.config/alacritty"
    "$HOME/.fehbg"
  )
  check_stale_paths "${dirs[@]}"
}

# Setup git identity
setup_git_identity() {
  log_step "configuring git identity"
  git config --global user.name  "Rodsantos1337"
  git config --global user.email "108137142+Rodsantos1337@users.noreply.github.com"
}

# Authenticate with gh (interactive, skipped if already authed)
auth_gh() {
  if ! gh auth status >/dev/null 2>&1; then
    log_step "gh authentication required"
    gh auth login -w -p https -h github.com
  fi
  gh auth setup-git --hostname github.com || true
}

# Authenticate with Tailscale (interactive, skipped if already joined)
auth_tailscale() {
  if ! sudo tailscale status >/dev/null 2>&1; then
    log_step "tailscale authentication required"
    sudo tailscale up
  fi
}

# Dev-install quillcode (pi fork, public repo)
install_quillcode() {
  local quillcode_dir="$HOME/base/quillcode"
  if [[ ! -d "$quillcode_dir/.git" ]]; then
    mkdir -p "$(dirname "$quillcode_dir")"
    log_step "cloning quillcode fork"
    if ! git clone https://github.com/Rodsantos1337/quillcode.git "$quillcode_dir"; then
      log_warn "quillcode clone failed - skipping"
      return 0
    fi
  else
    log_info "updating quillcode fork"
    git -C "$quillcode_dir" pull --ff-only
  fi
  # Install cline globally via npm
  if has_cmd npm; then
    log_step "installing cline globally"
    sudo npm install -g cline
  else
    log_warn "npm not found - skipping cline install"
  fi
}

# Dev-install llmserve (custom project)
install_llmserve() {
  local llmserve_dir="$HOME/base/llmserve"
  if [[ ! -d "$llmserve_dir/.git" ]]; then
    mkdir -p "$(dirname "$llmserve_dir")"
    log_step "cloning llmserve"
    if ! git clone https://github.com/Rodsantos1337/llmserve.git "$llmserve_dir"; then
      log_warn "llmserve clone failed - skipping"
      return 0
    fi
  else
    log_info "updating llmserve"
    git -C "$llmserve_dir" pull --ff-only
  fi
  # Run any setup script if present
  if [[ -f "$llmserve_dir/setup.sh" ]]; then
    log_step "running llmserve setup"
    bash "$llmserve_dir/setup.sh"
  elif [[ -f "$llmserve_dir/install.sh" ]]; then
    log_step "running llmserve install"
    bash "$llmserve_dir/install.sh"
  fi
}

# Privatize dotfiles repo (only on full success)
privatize_dotfiles() {
  if ! gh auth status >/dev/null 2>&1; then
    log_warn "gh not authenticated - leaving repo visibility as-is"
    return 0
  fi
  local vis
  vis="$(gh repo view Rodsantos1337/dotfiles --json visibility -q .visibility 2>/dev/null || echo "UNKNOWN")"
  if [[ "$vis" == "PUBLIC" ]]; then
    log_step "privatizing dotfiles repo"
    gh repo edit Rodsantos1337/dotfiles --visibility private --accept-visibility-change-consequences
  else
    log_info "dotfiles repo already $vis"
  fi
}
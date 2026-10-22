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

# Verify critical symlinks point to dotfiles repo (mirrors install.sh MAPPINGS)
verify_dotfile_links() {
  local dotfiles_dir="$1"
  local verify_rels=(
    ".bashrc" ".zshrc" ".xprofile" ".Xresources" ".fehbg"
    "Pictures/bg.jpg" "Pictures/bg-old.jpg" "Pictures/new.jpg" "Pictures/bg-newer.jpg"
    ".config/i3/config" ".config/i3/scripts"
    ".config/kitty" ".config/dunst" ".config/flameshot/flameshot.ini"
    ".config/fontconfig" ".config/gtk-3.0/settings.ini" ".config/gtk-4.0/settings.ini"
    ".config/opencode"
    ".config/picom" ".config/polybar" ".config/rofi" ".config/ttt" ".config/nvim"
    ".config/zed" ".config/alacritty"
    ".config/qutebrowser/config.py" ".config/xsettingsd"
    ".config/disable-mouse-accel.sh" ".config/mimeapps.list" ".config/user-dirs.dirs"
    ".config/user-dirs.locale" ".config/gamemode.ini"
    ".config/systemd" ".gitconfig"
    ".local/share/themes/Everforest-Green-Dark-Dim"
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
    "$HOME/.config/kitty"
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

# Dev-install quillcode (pi fork, public repo) - canonical dir is ~/base/quillcode
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

# Install ttt editor (single static binary to ~/.local/bin).
# Upstream has no dnf/copr package; official method is the install script.
# Idempotent: skips when `ttt --version` already works.
install_ttt() {
  if command -v ttt >/dev/null 2>&1 && ttt --version >/dev/null 2>&1; then
    log_info "ttt already installed ($(ttt --version 2>/dev/null | head -n 1))"
    return 0
  fi
  log_step "installing ttt editor"
  if ! curl -sSfL https://raw.githubusercontent.com/eugenioenko/ttt/main/install.sh | sh; then
    log_warn "ttt install failed - mod+o vault scratchpad will not work"
    return 0
  fi
  if command -v ttt >/dev/null 2>&1; then
    log_ok "ttt installed ($(ttt --version 2>/dev/null | head -n 1))"
  else
    log_warn "ttt installed but not on PATH - ensure ~/.local/bin is exported (see .xprofile)"
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

# Set zsh as the login shell when installed (idempotent).
setup_default_shell() {
  local zsh_path current
  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    log_warn "zsh not installed - keeping current login shell"
    return 0
  fi
  current="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current" == "$zsh_path" ]]; then
    log_info "login shell already $zsh_path"
    return 0
  fi
  log_step "setting login shell to $zsh_path"
  sudo chsh -s "$zsh_path" "$USER" || log_warn "chsh failed - set the login shell manually"
}

# Install marksman (Markdown LSP) from the upstream release. No Fedora package.
install_marksman() {
  if command -v marksman >/dev/null 2>&1; then
    log_info "marksman already installed"
    return 0
  fi
  local arch asset
  case "$(uname -m)" in
    x86_64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) log_warn "marksman: unsupported arch $(uname -m) - skipping"; return 0 ;;
  esac
  asset="marksman-linux-${arch}"
  log_step "installing marksman ($asset)"
  mkdir -p "$HOME/.local/bin"
  if curl -fsSL -o "$HOME/.local/bin/marksman" \
    "https://github.com/artempyanykh/marksman/releases/latest/download/$asset"; then
    chmod +x "$HOME/.local/bin/marksman"
    log_ok "marksman installed"
  else
    log_warn "marksman download failed - ttt markdown LSP will be unavailable"
  fi
}

# Install OpenCode plugin dependencies from the tracked package.json.
install_opencode_deps() {
  local dir="$HOME/.config/opencode"
  if [[ ! -f "$dir/package.json" ]]; then
    log_info "opencode package.json not found - skipping plugin deps"
    return 0
  fi
  if ! has_cmd npm; then
    log_warn "npm not found - skipping opencode plugin deps"
    return 0
  fi
  log_step "installing opencode plugin dependencies"
  (cd "$dir" && npm install --no-audit --no-fund) || log_warn "opencode npm install failed"
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
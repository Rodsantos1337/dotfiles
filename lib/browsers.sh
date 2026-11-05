#!/usr/bin/env bash
#
# lib/browsers.sh - Browser installation logic
# Source after common.sh

# Install Zen browser via COPR
install_browsers() {
  log_step "installing third-party apps (Zen browser)"

  # Zen via COPR sneexy/zen-browser (repos enabled in setup.sh)
  sudo dnf install -y zen-browser || log_warn "browser install had issues - check repos"
}

# Install Tailscale
install_tailscale() {
  if ! has_cmd tailscale; then
    log_info "installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
}

# Install opencode
install_opencode() {
  if ! has_cmd opencode; then
    log_info "installing opencode"
    curl -fsSL https://opencode.ai/install | bash
  fi
}

# Install Nerd Fonts via release zips
install_nerd_fonts() {
  if ! fc-list | grep -qi 'GeistMono Nerd' || ! fc-list | grep -qi 'JetBrainsMono Nerd'; then
    log_step "installing GeistMono + JetBrainsMono Nerd Fonts"
    local tmpfonts
    tmpfonts="$(mktemp -d)"
    sudo mkdir -p /usr/local/share/fonts
    for font in GeistMono JetBrainsMono; do
      if ! fc-list | grep -qi "$font Nerd"; then
        curl -fsSL -o "$tmpfonts/$font.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.zip"
        sudo unzip -o -q "$tmpfonts/$font.zip" -d "/usr/local/share/fonts/$font"
      fi
    done
    sudo fc-cache -f >/dev/null
    rm -rf "$tmpfonts"
  fi
}

# Install Everforest-Dark icons
install_everforest_icons() {
  if [[ ! -d "$HOME/.local/share/icons/Everforest-Dark" ]]; then
    log_info "installing Everforest-Dark icons"
    mkdir -p "$HOME/.local/share/icons"
    if git clone --depth 1 https://github.com/ItzSelenux/everforest-icon-theme "/tmp/everforest-icons"; then
      cp -r /tmp/everforest-icons/Everforest-Dark "$HOME/.local/share/icons/" 2>/dev/null || true
      rm -rf /tmp/everforest-icons
    else
      log_warn "everforest icons clone failed - set icons manually"
    fi
  fi
}
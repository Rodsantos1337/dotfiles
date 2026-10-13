#!/usr/bin/env bash
#
# lib/browsers.sh - Browser installation logic
# Source after common.sh

# Install browsers for Arch
install_arch_browsers() {
  log_step "installing AUR packages (browsers + icons + theme engine)"
  # Ensure yay is available
  if ! has_cmd yay; then
    log_err "yay not found - run setup.sh first"
    return 1
  fi
  yay -S --needed helium-browser-bin vscodium-bin everforest-icon-theme-git gtk-engine-murrine
}

# Install browsers for Fedora
install_fedora_browsers() {
  log_step "installing third-party apps (VSCodium + browser)"

  # VSCodium + Zen/Helium via repos enabled in setup.sh
  # Note: helium-browser may not be in Fedora COPR; fallback to zen-browser
  if dnf list helium-browser >/dev/null 2>&1; then
    sudo dnf install -y helium-browser codium
  else
    log_warn "helium-browser not in Fedora repos - installing zen-browser instead"
    sudo dnf install -y zen-browser codium || log_warn "browser install had issues - check repos"
  fi
}

# Install Tailscale (Fedora only - Arch uses package)
install_tailscale_fedora() {
  if ! has_cmd tailscale; then
    log_info "installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
}

# Install opencode (Fedora only - Arch uses package)
install_opencode_fedora() {
  if ! has_cmd opencode; then
    log_info "installing opencode"
    curl -fsSL https://opencode.ai/install | bash
  fi
}

# Install Nerd Fonts on Fedora (Arch has them packaged)
install_nerd_fonts_fedora() {
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

# Install Everforest icons on Fedora (Arch has AUR package)
install_everforest_icons_fedora() {
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
#!/usr/bin/env bash
#
# lib/theming.sh - GTK theming via gsettings + XFCE config
# Source after common.sh

# Apply Salvia-Dim theming (GTK theme + icons + color scheme)
apply_salvia_theming() {
  log_step "applying Salvia-Dim theming (gsettings)"
  gsettings set org.gnome.desktop.interface icon-theme 'Everforest-Dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Salvia-Dim'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface cursor-size 14
  gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
  gsettings set org.gnome.desktop.peripherals.touchpad accel-profile 'flat'
}

# Configure XFCE to use kitty as default terminal (for Thunar "Open Terminal Here")
setup_xfce_terminal() {
  if ! has_cmd xfconf-query; then
    log_warn "xfconf-query not found, skipping XFCE terminal config"
    return 0
  fi
  log_step "configuring XFCE terminal emulator -> kitty"
  # Set preferred terminal for exo (used by Thunar, xfce4-session, etc.)
  xfconf-query -c xfce4-session -p /general/TerminalEmulator -s "kitty" --create -t string 2>/dev/null || true
  # Also set the custom terminal command (some tools read this)
  xfconf-query -c xfce4-session -p /general/TerminalCommand -s "kitty" --create -t string 2>/dev/null || true
  # Ensure xfce4-terminal wrapper uses kitty (for apps that hardcode xfce4-terminal)
  xfconf-query -c xfce4-terminal -p /misc/default-command -s "kitty" --create -t string 2>/dev/null || true
}

# Set keyboard layout to PT (TTY + X11 + session fallback)
setup_keyboard_pt() {
  log_step "setting keyboard layout (pt)"
  sudo localectl set-keymap pt-latin1
  sudo localectl set-x11-keymap pt
  # Session fallback in .xprofile + i3 config (setxkbmap -layout pt)
}

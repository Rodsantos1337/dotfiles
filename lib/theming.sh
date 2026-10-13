#!/usr/bin/env bash
#
# lib/theming.sh - GTK theming via gsettings
# Source after common.sh

# Apply Everforest theming (GTK theme + icons + color scheme)
apply_everforest_theming() {
  log_step "applying Everforest theming (gsettings)"
  gsettings set org.gnome.desktop.interface icon-theme 'Everforest-Dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Everforest-Green-Dark-Dim'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface cursor-size 14
  gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
  gsettings set org.gnome.desktop.peripherals.touchpad accel-profile 'flat'
}

# Set keyboard layout to PT (TTY + X11 + session fallback)
setup_keyboard_pt() {
  log_step "setting keyboard layout (pt)"
  sudo localectl set-keymap pt-latin1
  sudo localectl set-x11-keymap pt
  # Session fallback in .xprofile + i3 config (setxkbmap -layout pt)
}
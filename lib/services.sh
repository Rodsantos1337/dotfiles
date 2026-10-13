#!/usr/bin/env bash
#
# lib/services.sh - Service enablement logic
# Source after common.sh and packages.sh

# Enable common services for all variants
enable_common_services() {
  log_step "enabling common services"
  sysctl_enable_now power-profiles-daemon
  sysctl_enable_now ufw

  # tailscale mesh + syncthing
  sysctl_enable_now tailscaled
  sudo ufw allow in on tailscale0 comment 'tailnet' 2>/dev/null || sudo ufw allow in on tailscale0 || true

  sysctl_user_enable_now syncthing.service
  sudo loginctl enable-linger "$USER"
  mkdir -p "$HOME/vault"
  log_info "syncthing web UI: http://localhost:8384 (add phone, share ~/vault)"
}

# Enable display manager (Arch only - Fedora keeps its own)
enable_display_manager() {
  local distro="$1"
  if [[ "$distro" == "arch" ]]; then
    if ! systemctl is-enabled display-manager >/dev/null 2>&1; then
      log_info "enabling ly@tty1"
      sudo systemctl enable ly@tty1
    else
      log_info "display-manager already enabled, skipping ly"
    fi
  fi
}

# Enable laptop-specific services
enable_laptop_services() {
  local distro="$1"
  if [[ "$distro" == "arch" ]]; then
    # fans-guard is installed by fans-g5-kf installer
    if systemctl list-unit-files | grep -q fans-guard; then
      sysctl_enable_now fans-guard
    fi
  elif [[ "$distro" == "fedora" ]]; then
    sysctl_enable_now thermald || log_warn "thermald enable failed"
    # Disable firewalld to avoid double-firewall conflicts
    if systemctl is-enabled firewalld >/dev/null 2>&1; then
      sudo systemctl disable --now firewalld || true
    fi
  fi
}

# Disable firewalld on Fedora (use ufw instead)
disable_firewalld_if_fedora() {
  local distro="$1"
  if [[ "$distro" == "fedora" ]]; then
    if systemctl is-enabled firewalld >/dev/null 2>&1; then
      log_info "disabling firewalld (using ufw)"
      sudo systemctl disable --now firewalld || true
    fi
  fi
}
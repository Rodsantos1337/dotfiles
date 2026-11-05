#!/usr/bin/env bash
#
# lib/services.sh - Service enablement logic (Fedora)
# Source after common.sh and packages.sh

# Enable common services for all variants (uses ufw, not firewalld)
enable_common_services() {
  log_step "enabling common services"
  sysctl_enable_now power-profiles-daemon
  sysctl_enable_now ufw

  if systemctl is-enabled firewalld >/dev/null 2>&1; then
    log_info "disabling firewalld (using ufw)"
    sudo systemctl disable --now firewalld || true
  fi

  # tailscale mesh + syncthing
  sysctl_enable_now tailscaled
  sudo ufw allow in on tailscale0 comment 'tailnet' 2>/dev/null || sudo ufw allow in on tailscale0 || true

  sysctl_user_enable_now syncthing.service
  sudo loginctl enable-linger "$USER"
  mkdir -p "$HOME/vault" "$HOME/base/ACI/screenshots"
  log_info "syncthing web UI: http://localhost:8384 (add phone, share ~/vault)"
}

# Enable display manager (Fedora keeps LightDM + GTK greeter)
enable_display_manager() {
  if systemctl is-enabled display-manager >/dev/null 2>&1; then
    log_info "display manager already enabled"
  else
    log_info "no display manager enabled - installing lightdm"
    if sudo dnf install -y lightdm lightdm-gtk; then
      sudo systemctl enable lightdm || log_warn "lightdm enable failed"
    else
      log_warn "lightdm install failed - start i3 manually or install a greeter"
    fi
  fi
}

# Enable laptop-specific services (no-op on desktop)
enable_laptop_services() {
  local variant="$1"
  if [[ "$variant" == "laptop" ]]; then
    sysctl_enable_now thermald || log_warn "thermald enable failed"
  fi
}

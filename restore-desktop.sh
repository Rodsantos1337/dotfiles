#!/usr/bin/env bash
#
# restore-desktop.sh - Restore Fedora i3 desktop after `dnf remove` (transaction 29)
#
# What happened:
#   dnf remove abrt-cli abrt-desktop lightdm lightdm-gtk
#     lightdm-gtk-greeter-settings plymouth plymouth-system-theme
#     lxappearance azote cups cups-browsed cups-filters cups-pk-helper
#     gutenprint-cups hplip
#   pulled ~111 packages via dependencies and left lightdm disabled,
#   so the machine boots to TTY with no X session (hence "no cursor").
#
# What this does (idempotent, safe to re-run):
#   1. Reinstalls display manager, boot splash, Xorg, i3 stack,
#      fonts, cursor theme, screenshots, printing.
#   2. Fixes XCURSOR_SIZE mismatch (.xprofile said 14, .Xresources says 24).
#   3. Re-enables lightdm + graphical.target and rebuilds plymouth theme.
#   4. Verifies i3 config and key binaries.
#
# Usage (from TTY, e.g. Ctrl+Alt+F3, no mouse needed):
#   chmod +x restore-desktop.sh
#   ./restore-desktop.sh
#   sudo reboot
#
# After reboot: LightDM greeter -> login -> i3.
# If cursor still missing once in i3, run once:
#   xsetroot -cursor_name left_ptr
#

set -euo pipefail

log()  { printf '\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 0. Preflight
# ---------------------------------------------------------------------------
if [[ "${EUID}" -eq 0 ]]; then
  warn "Do not run as root - run as your normal user (sudo is used internally)."
  exit 1
fi

if ! grep -qi '^ID=fedora' /etc/os-release 2>/dev/null; then
  warn "This script is for Fedora only. Detected: $(cat /etc/os-release 2>/dev/null | head -n 2)"
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Reinstall desktop-critical packages
# ---------------------------------------------------------------------------
log "1/4 installing missing + desktop-critical packages"

sudo dnf install -y \
  `# --- display manager + greeter ---` \
  lightdm lightdm-gtk lightdm-gtk-greeter-settings \
  accountsservice \
  `# --- boot splash ---` \
  plymouth plymouth-system-theme plymouth-theme-spinner \
  `# --- Xorg session ---` \
  xorg-x11-server-Xorg xorg-x11-xinit xsetroot \
  xrandr xrdb xinput setxkbmap \
  xsettingsd \
  `# --- GTK theming / session helpers ---` \
  lxappearance lxsession \
  `# --- wallpaper / screenshots ---` \
  azote feh maim slop ImageMagick \
  `# --- fonts (i3 config uses Inter, bar needs icons) ---` \
  dejavu-sans-fonts open-sans-fonts abattis-cantarell-fonts \
  rsms-inter-fonts jetbrains-mono-fonts fontawesome4-fonts \
  `# --- cursor (fixes invisible cursor) ---` \
  adwaita-cursor-theme adwaita-icon-theme \
  `# --- printing (drop these 6 lines if you don't print) ---` \
  cups cups-browsed cups-filters cups-pk-helper gutenprint-cups hplip \
  poppler-utils \
  `# --- i3 stack (re-assert, should already be present) ---` \
  i3 i3blocks dmenu i3lock xss-lock \
  kitty dunst picom polybar rofi flameshot \
  network-manager-applet pavucontrol brightnessctl Thunar \
  lm_sensors power-profiles-daemon \
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-utils

# ---------------------------------------------------------------------------
# 2. Fix cursor + Xresources
# ---------------------------------------------------------------------------
log "2/4 fixing cursor + Xresources"

# Align .xprofile with .Xresources (24) so GTK/Qt/X all agree.
if [[ -f "$HOME/.xprofile" ]]; then
  if grep -q 'XCURSOR_SIZE' "$HOME/.xprofile"; then
    sed -i 's/export XCURSOR_SIZE=.*/export XCURSOR_SIZE=24/' "$HOME/.xprofile"
  else
    echo 'export XCURSOR_SIZE=24' >> "$HOME/.xprofile"
  fi
fi

if [[ -f "$HOME/.Xresources" ]]; then
  grep -q 'Xcursor.theme' "$HOME/.Xresources" || {
    printf '%s\n' 'Xcursor.theme: Adwaita' 'Xcursor.size: 24' >> "$HOME/.Xresources"
  }
fi

# Merge now if X is running (no-op on pure TTY, ignore failure).
xrdb -merge "$HOME/.Xresources" 2>/dev/null || true

# Force a visible root cursor even if WM hasn't set one yet.
# (xsetroot is its own package on Fedora 44 - xorg-x11-server-utils was retired.)
xsetroot -cursor_name left_ptr 2>/dev/null || warn "xsetroot could not set cursor (expected if no X session yet)."

# ---------------------------------------------------------------------------
# 3. Re-enable graphical boot + LightDM
# ---------------------------------------------------------------------------
log "3/4 enabling graphical boot + LightDM"

sudo plymouth-set-default-theme spinner -R || warn "plymouth theme rebuild failed (non-fatal)."

sudo systemctl enable lightdm
sudo systemctl set-default graphical.target

# ---------------------------------------------------------------------------
# 4. Verify
# ---------------------------------------------------------------------------
log "4/4 verifying i3 stack"

I3_CONFIG="$HOME/.config/i3/config"
if [[ -f "$I3_CONFIG" ]]; then
  if i3 -C -c "$I3_CONFIG"; then
    echo "i3 config OK"
  else
    warn "i3 config check FAILED - run: i3 -C -c $I3_CONFIG"
  fi
else
  warn "i3 config not found at $I3_CONFIG"
fi

echo "--- binaries ---"
for bin in Xorg startx i3 polybar picom feh rofi dunst nm-applet xsetroot xrdb; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "OK   $bin -> $(command -v "$bin")"
  else
    warn "MISS $bin"
  fi
done

echo "--- services ---"
systemctl is-enabled lightdm || true
systemctl is-enabled NetworkManager || true
systemctl is-enabled accounts-daemon || true

echo ""
log "Done. Reboot now: sudo reboot"
echo "After reboot you should get LightDM -> login -> i3."
echo "If cursor is still missing in i3, run once: xsetroot -cursor_name left_ptr"

#!/usr/bin/env bash
#
# fix-boot-i3.sh - One-shot fix so next boot lands in LightDM -> i3
#
# TTY usage (no copy/paste needed):
#   sudo ~/dotfiles/fix-boot-i3.sh
#   (type password once, it does everything, then reboot when told)
# Also works without sudo: ./fix-boot-i3.sh (will use sudo internally).
#
# What it does (idempotent, safe to re-run):
#   1. Installs the missing dnf packages (greeter, xsetroot, azote, ImageMagick).
#      NOTE (Fedora 44): the greeter package is `lightdm-gtk` (provides
#      /usr/bin/lightdm-gtk-greeter) - `lightdm-gtk-greeter` does not exist.
#      Likewise `xorg-x11-server-utils` was retired - the Cursor fix binary
#      `xsetroot` now ships in the standalone `xsetroot` package.
#   2. Copies ~/dotfiles/wallpapers/new.jpg (your i3 wallpaper) to
#      /usr/share/backgrounds/i3-new.jpg so the lightdm system user can read it
#      ($HOME is 0700, so pointing the greeter at ~/Pictures would stay black).
#   3. Pins LightDM: greeter-session=lightdm-gtk-greeter, user-session=i3.
#   4. Sets greeter background to the same image as i3 + disables per-user bg flicker.
#   5. Enables lightdm + graphical.target, rebuilds plymouth spinner theme.
#   6. Verifies i3 config, binaries and service state.
#
# After reboot: LightDM greeter on new.jpg -> login -> pick "i3" in the
# session menu once (it sticks via ~/.dmrc afterwards).

set -euo pipefail

# Resolve the real (non-root) user even when launched via `sudo script`.
# SUDO_USER is set by sudo; fallback chain covers su / direct root (not expected).
REAL_USER="${SUDO_USER:-${USER:-$(id -un 2>/dev/null || echo root)}}"
if [[ "$REAL_USER" == "root" ]]; then
  # last resort: owner of the dotfiles dir
  REAL_USER="$(stat -c '%U' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 2>/dev/null || echo root)"
fi
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[[ -n "${REAL_HOME:-}" && -d "$REAL_HOME" ]] || REAL_HOME="$HOME"

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALL_SRC="$DOTFILES_DIR/wallpapers/new.jpg"
WALL_DST="/usr/share/backgrounds/i3-new.jpg"
I3_CONFIG="$REAL_HOME/.config/i3/config"
DMRC="$REAL_HOME/.dmrc"

log()  { printf '\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }

# Helper: run as root if we are root, else via sudo (password asked once).
as_root() {
  if [[ "${EUID}" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

if ! grep -qi '^ID=fedora' /etc/os-release 2>/dev/null; then
  warn "Fedora-only script. Detected: $(head -n 2 /etc/os-release 2>/dev/null)"
  exit 1
fi

if [[ ! -f "$WALL_SRC" ]]; then
  warn "Wallpaper not found: $WALL_SRC"
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Missing dnf packages (everything else in the i3 stack is already installed)
# ---------------------------------------------------------------------------
log "1/6 installing missing packages"
as_root dnf install -y \
  lightdm \
  lightdm-gtk \
  xsetroot \
  azote \
  ImageMagick

# ---------------------------------------------------------------------------
# 2. World-readable greeter background (same image as i3)
# ---------------------------------------------------------------------------
log "2/6 installing greeter background (same as i3: new.jpg)"
as_root install -m 0644 "$WALL_SRC" "$WALL_DST"
echo "greeter bg -> $WALL_DST"

# ---------------------------------------------------------------------------
# 3. Pin LightDM seat to GTK greeter + i3 session
# ---------------------------------------------------------------------------
log "3/6 pinning LightDM seat to greeter + i3"
as_root mkdir -p /etc/lightdm/lightdm.conf.d
as_root tee /etc/lightdm/lightdm.conf.d/10-i3.conf >/dev/null <<'EOF'
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=i3
EOF
echo "wrote /etc/lightdm/lightdm.conf.d/10-i3.conf"

# ---------------------------------------------------------------------------
# 4. Greeter theme: same wallpaper, no per-user-background flicker
# ---------------------------------------------------------------------------
log "4/6 theming GTK greeter"
GREETER_CONF="/etc/lightdm/lightdm-gtk-greeter.conf"
# Ensure a [greeter] section exists, then (up)sert the two keys.
if ! grep -q '^\[greeter\]' "$GREETER_CONF" 2>/dev/null; then
  echo -e '\n[greeter]' | as_root tee -a "$GREETER_CONF" >/dev/null
fi
as_root python3 - "$GREETER_CONF" "$WALL_DST" <<'PY'
import configparser, sys
path, bg = sys.argv[1], sys.argv[2]
cp = configparser.ConfigParser(strict=False, interpolation=None)
cp.optionxform = str  # keep key case
cp.read(path)
if 'greeter' not in cp:
    cp['greeter'] = {}
cp['greeter']['background'] = bg
cp['greeter']['user-background'] = 'false'
with open(path, 'w') as f:
    cp.write(f)
PY
echo "greeter background -> $WALL_DST (user-background=false)"

# ---------------------------------------------------------------------------
# 5. Enable graphical boot path + preselect i3 so no session-menu pick needed
# ---------------------------------------------------------------------------
log "5/6 enabling lightdm + graphical.target"
as_root systemctl enable lightdm
as_root systemctl set-default graphical.target
as_root plymouth-set-default-theme spinner -R || warn "plymouth theme rebuild failed (non-fatal)."
# Preselect i3 for LightDM (sticks via ~/.dmrc) so next login goes straight to i3.
# Always write as the real user, even when the whole script runs under sudo.
printf '[Desktop]\nSession=i3\n' > "$DMRC"
chmod 644 "$DMRC"
if [[ "${EUID}" -eq 0 ]]; then chown "$REAL_USER:$REAL_USER" "$DMRC"; fi
echo "wrote $DMRC (Session=i3, owner $REAL_USER)"

# ---------------------------------------------------------------------------
# 6. Verify
# ---------------------------------------------------------------------------
log "6/6 verifying"

if [[ -f "$I3_CONFIG" ]]; then
  if i3 -C -c "$I3_CONFIG"; then
    echo "OK   i3 config"
  else
    warn "i3 config check FAILED - run: i3 -C -c $I3_CONFIG"
  fi
else
  warn "i3 config not found at $I3_CONFIG"
fi

echo "--- packages ---"
for pkg in lightdm lightdm-gtk xsetroot azote ImageMagick i3; do
  if rpm -q "$pkg" >/dev/null 2>&1; then
    echo "OK   $(rpm -q "$pkg")"
  else
    warn "MISS $pkg"
  fi
done
# xsetroot binary check (the actual file restore-desktop.sh cares about)
command -v xsetroot >/dev/null 2>&1 && echo "OK   xsetroot -> $(command -v xsetroot)" || warn "MISS xsetroot binary"

echo "--- greeter background ---"
ls -l "$WALL_DST" || warn "missing $WALL_DST"
grep -E '^(background|user-background)' "$GREETER_CONF" || warn "greeter keys not found in $GREETER_CONF"

echo "--- seat config ---"
cat /etc/lightdm/lightdm.conf.d/10-i3.conf

echo "--- services ---"
systemctl is-enabled lightdm || true
systemctl get-default || true
ls -l /etc/systemd/system/display-manager.service || true

echo ""
log "Done. Reboot now with: sudo reboot"
log "After reboot: LightDM greeter (new.jpg) -> login -> i3 (preselected via $DMRC)."

#!/usr/bin/env bash
#
# setup-laptop-fedora.sh - provision a fresh Fedora (minimal + i3) LAPTOP
#
# LAPTOP VARIANT: identical to install-fedora.sh plus generic laptop power
# tooling (thermald + powertop + acpi). No Gigabyte G5 KF fan control
# (fans-g5-kf) or keyboard backlight (kbl) wiring by design.
# On desktops run install-fedora.sh instead.
#
# No display manager handling: whatever Fedora already ships
# (LightDM/SDDM/GDM from the Spin/netinstall) is kept.
#
# Usage: ./setup-laptop-fedora.sh   (run as your normal user; sudo is invoked where needed)
# Idempotent: dnf skips installed pkgs; install.sh skips existing links.

set -euo pipefail

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "error: run as your normal user (sudo is invoked where needed)" >&2
  exit 1
fi

if [[ ! -f /etc/fedora-release ]]; then
  echo "error: this script targets Fedora (no /etc/fedora-release found)" >&2
  exit 1
fi

# --- 0. system upgrade ---------------------------------------------------------
echo "== [0/10] system upgrade =="
sudo dnf upgrade --refresh -y

# --- 1. third-party repos ------------------------------------------------------
# RPM Fusion (free + nonfree): steam + media codecs territory.
# VSCodium: official upstream repo (package name: codium).
# Zen Browser: sneexy/zen-browser COPR.
# Tailscale: official upstream repo via their install script (run in step 3).
echo "== [1/10] third-party repos =="
FEDORA_VER="$(rpm -E %fedora)"
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
  || echo "warning: rpmfusion install failed (already enabled?) - continuing" >&2
sudo dnf install -y dnf-plugins-core curl wget
# VSCodium official repo
if [[ ! -f /etc/yum.repos.d/vscodium.repo ]]; then
  sudo curl --output-dir /etc/yum.repos.d -fsSL -O https://repo.vscodium.dev/vscodium.repo
fi
# Zen Browser COPR (x86_64 stable; aarch64 uses same repo, pkg zen-browser)
if ! sudo dnf copr list --enabled 2>/dev/null | grep -q 'sneexy/zen-browser'; then
  sudo dnf copr enable -y sneexy/zen-browser
fi

# --- 2. dnf packages -----------------------------------------------------------
# NOTE: python3-gobject is an *optional* dep of power-profiles-daemon but
# powerprofilesctl requires it (else: ModuleNotFoundError: gi.repository).
# NOTE: gtk-murrine-engine IS in official Fedora so it stays in this list.
# NOTE: no display manager in this list by design - keep Fedora's own.
DNF_PKGS=(
  # build/clone toolchain
  gcc gcc-c++ make kernel-devel git curl wget
  # fzf: Ctrl+R history, Ctrl+T files, Alt+C dirs; zoxide: `z <fragment>` jumps
  fzf zoxide
  python3-gobject pipx
  # session / window manager
  i3 i3blocks dmenu i3lock xss-lock
  xorg-x11-server-Xorg xorg-x11-xinit xrandr xrdb xinput
  # system UI
  alacritty dunst picom xsettingsd feh flameshot polybar rofi
  # brightness OSD: i3 fn-keys -> scripts/brightness needs brightnessctl +
  # notify-send (libnotify)
  brightnessctl libnotify
  gtk-murrine-engine
  network-manager-applet power-profiles-daemon lm_sensors pavucontrol
  # portals/xdg: screen sharing, file dialogs, open-with handlers
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-utils
  # fonts (GeistMono Nerd + JetBrainsMono Nerd arrive via manual zip in step 3)
  jetbrains-mono-fonts rsms-inter-fonts fontawesome4-fonts
  # apps (opencode + zen + codium arrive in step 3; steam via RPM Fusion)
  Thunar nano neovim steam
  # JS runtime (Fedora 44 ships versioned nodejs streams)
  nodejs22 nodejs22-npm
  # tools (gh is Fedora's name for Arch's github-cli)
  htop wget gh ufw unzip bluez bluez-tools smartmontools zram-generator efibootmgr syncthing
  # laptop: generic power/thermal telemetry (no fan/kbl vendor wiring)
  thermald powertop acpi
)
echo "== [2/10] dnf packages =="
# full dnf output lands in this log so failures are always debuggable
DNF_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/setup-fedora-dnf.log"
{
  echo "=== setup-laptop-fedora.sh run $(date -Iseconds) ==="
  sudo dnf install -y "${DNF_PKGS[@]}"
} |& tee -a "$DNF_LOG"

# --- 3. third-party apps (missing from Fedora) ---------------------------------
echo "== [3/10] third-party apps =="
# VSCodium + Zen via the repos enabled in step 1
sudo dnf install -y codium zen-browser || echo "warning: codium/zen install had issues - check repos" >&2
# Tailscale official repo + install (idempotent)
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
# opencode: no Fedora package; official installer (idempotent, re-runnable)
if ! command -v opencode >/dev/null 2>&1; then
  curl -fsSL https://opencode.ai/install | bash
fi
# Nerd Fonts (GeistMono + JetBrainsMono): not packaged in Fedora; unzip the
# official nerd-fonts zips into /usr/local/share/fonts (system-wide so all
# users/DMs see them). Skipped if both families already present.
if ! fc-list | grep -qi 'GeistMono Nerd' || ! fc-list | grep -qi 'JetBrainsMono Nerd'; then
  echo "installing GeistMono + JetBrainsMono Nerd Fonts"
  TMPFONTS="$(mktemp -d)"
  sudo mkdir -p /usr/local/share/fonts
  for F in GeistMono JetBrainsMono; do
    if ! fc-list | grep -qi "$F Nerd"; then
      curl -fsSL -o "$TMPFONTS/$F.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$F.zip"
      sudo unzip -o -q "$TMPFONTS/$F.zip" -d "/usr/local/share/fonts/$F"
    fi
  done
  sudo fc-cache -f >/dev/null
  rm -rf "$TMPFONTS"
fi
# Everforest-Dark icons: not packaged in Fedora; best-effort clone into
# ~/.local/share/icons (non-fatal - GTK theme itself is vendored in this repo).
if [[ ! -d "$HOME/.local/share/icons/Everforest-Dark" ]]; then
  mkdir -p "$HOME/.local/share/icons"
  if git clone --depth 1 https://github.com/ItzSelenux/everforest-icon-theme "/tmp/everforest-icons"; then
    cp -r /tmp/everforest-icons/Everforest-Dark "$HOME/.local/share/icons/" 2>/dev/null || true
    rm -rf /tmp/everforest-icons
  else
    echo "warning: everforest icons clone failed - set icons manually" >&2
  fi
fi

# --- 4. laptop power services --------------------------------------------------
# Generic laptop thermal/power telemetry only. No G5 KF fan/kbl wiring.
echo "== [4/10] laptop power services =="
sudo systemctl enable --now thermald || echo "warning: thermald enable failed" >&2

# --- 5. services ---------------------------------------------------------------
echo "== [5/10] services =="
sudo systemctl enable --now power-profiles-daemon
# Fedora defaults to firewalld; this setup uses ufw like the Arch side.
# Disable firewalld to avoid double-firewall conflicts, then enable ufw.
if systemctl is-enabled firewalld >/dev/null 2>&1; then
  sudo systemctl disable --now firewalld || true
fi
sudo systemctl enable --now ufw
# tailscale mesh + syncthing (vault sync to phone; pairing via web UI)
sudo systemctl enable --now tailscaled
sudo ufw allow in on tailscale0 comment 'tailnet' || sudo ufw allow in on tailscale0 || true
systemctl --user enable --now syncthing.service
sudo loginctl enable-linger "$USER"   # syncthing syncs from boot, pre-login
mkdir -p "$HOME/vault"                # sync target (mod+o / mod+Shift+o)
echo "syncthing web UI: http://localhost:8384 (add phone, share ~/vault)"
# NOTE: no display-manager step - keep Fedora's own (LightDM/SDDM/GDM).

# --- 6. gsettings (dconf) ------------------------------------------------------
# The Everforest GTK theme alone is NOT enough: portal-aware apps
# (e.g. Firefox "System theme - auto") read color-scheme from gsettings
# and flip to light unless it is set here.
echo "== [6/10] gsettings =="
gsettings set org.gnome.desktop.interface icon-theme 'Everforest-Dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Everforest-Green-Dark-Dim'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-size 14
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.touchpad accel-profile 'flat'

# --- 6b. keyboard: pt-pt everywhere (TTY + X11/login + session fallback) -----
echo "== [6b/10] keyboard (pt) =="
sudo localectl set-keymap pt-latin1
sudo localectl set-x11-keymap pt
# session fallback lives in .xprofile + i3 config (setxkbmap -layout pt)

# --- 7. git identity + gh auth ----------------------------------------------
echo "== [7/10] git identity + gh auth =="
git config --global user.name  "Rodsantos1337"
git config --global user.email "108137142+Rodsantos1337@users.noreply.github.com"
# interactive fallback: opens the browser; skipped if already authed
if ! gh auth status >/dev/null 2>&1; then
  echo "gh: not authenticated - starting browser login"
  gh auth login -w -p https -h github.com
fi
# tailscale: interactive browser login, skipped if already joined
if ! sudo tailscale status >/dev/null 2>&1; then
  echo "tailscale: not authenticated - starting browser login"
  sudo tailscale up
fi

# --- 8. dotfiles -----------------------------------------------------------------
REPO_URL="https://github.com/Rodsantos1337/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
echo "== [8/10] dotfiles =="
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  git -C "$DOTFILES_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi
"$DOTFILES_DIR/install.sh"

# --- 8b. verify configs linked ---------------------------------------------------
# install.sh is idempotent and backs up pre-existing files; confirm the key
# links actually resolve to this repo so a silent skip never goes unnoticed.
echo "== [8b/10] verify dotfile links =="
VERIFY_RELS=(
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
)
VERIFY_FAIL=0
for REL in "${VERIFY_RELS[@]}"; do
  DEST="$HOME/$REL"
  if [[ -L "$DEST" && "$(readlink "$DEST")" == "$DOTFILES_DIR/"* ]]; then
    echo "ok:   $REL -> $(readlink "$DEST")"
  else
    echo "MISS: $REL (not linked to \$DOTFILES_DIR)" >&2
    VERIFY_FAIL=1
  fi
done
if [[ $VERIFY_FAIL -ne 0 ]]; then
  echo "warning: some configs are not linked - re-run $DOTFILES_DIR/install.sh" >&2
fi

# --- 9. quill (dev install, editable) -----------------------------------------
# quill is a private repo: requires gh auth from step 6. Non-fatal so a
# failed clone/install never blocks the privatize step below.
echo "== [9/10] quill dev install =="
QUILL_DIR="$HOME/base/quill"
if [[ ! -d "$QUILL_DIR/.git" ]]; then
  mkdir -p "$(dirname "$QUILL_DIR")"
  if ! git clone https://github.com/Rodsantos1337/quill.git "$QUILL_DIR"; then
    echo "warning: quill clone failed (private repo? gh authed?) - skipping" >&2
  fi
fi
if [[ -d "$QUILL_DIR/.git" ]] && ! pipx list | grep -q '^quill'; then
  pipx install -e "$QUILL_DIR"
fi

# --- 10. re-privatize dotfiles repo ---------------------------------------------
# The repo was made public pre-install so it could be cloned without auth.
# Only flip back on full success: a failed run leaves it public/inspectable.
echo "== [10/10] privatize dotfiles repo =="
if ! gh auth status >/dev/null 2>&1; then
  echo "warning: gh not authenticated - leaving repo visibility as-is" >&2
else
  VIS="$(gh repo view Rodsantos1337/dotfiles --json visibility -q .visibility)"
  if [[ "$VIS" == "PUBLIC" ]]; then
    gh repo edit Rodsantos1337/dotfiles --visibility private \
      --accept-visibility-change-consequences
  else
    echo "already $VIS, skipping"
  fi
fi

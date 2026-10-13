#!/usr/bin/env bash
#
# install.sh - restore rod's Everforest i3wm dotfiles
#
# Symlinks config files from this repo into $HOME. It does NOT install
# any packages - run the arch/ or fedora/ setup script for provisioning.
#
# Usage:  ~/dotfiles/install.sh [--desktop|--laptop] [--no-verify]
# Idempotent: safe to re-run. Existing files are backed up first.
# --desktop / --laptop selects the i3 per-machine monitor variant
# (~/.config/i3/local -> monitors-desktop / monitors-laptop).
# Default: hostname heuristic (hostname 'fedora' = desktop, else laptop).

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)}"

# Format: either "repo/rel/path" (same relative path in $HOME) or
# "repo/rel/path:home/rel/path" for files that map elsewhere.
MAPPINGS=(
  ".xprofile"
  ".Xresources"
  ".bashrc"
  ".fehbg"
  "wallpapers/bg.jpg:Pictures/bg.jpg"
  "wallpapers/bg-old.jpg:Pictures/bg-old.jpg"
  "wallpapers/new.jpg:Pictures/new.jpg"
  ".config/i3/config"
  ".config/i3/scripts"
  ".config/alacritty"
  ".config/dunst"
  ".config/flameshot/flameshot.ini"
  ".config/fontconfig"
  ".config/gtk-3.0/settings.ini"
  ".config/gtk-4.0/settings.ini"
  ".config/opencode/themes"
  ".config/opencode/tui.json"
  ".config/picom"
  ".config/polybar"
  ".config/rofi"
  ".config/ttt"
  ".config/nvim"
  ".config/VSCodium"
  ".config/qutebrowser/config.py"
  ".vscode-oss/argv.json"
  ".config/xsettingsd"
  ".config/disable-mouse-accel.sh"
  "themes/Everforest-Green-Dark-Dim:.local/share/themes/Everforest-Green-Dark-Dim"
)

link_one() {
  local mapping="$1" src rel
  if [[ "$mapping" == *:* ]]; then
    src="${mapping%%:*}"
    rel="${mapping#*:}"
  else
    src="$mapping"
    rel="$mapping"
  fi

  local src_abs="$DOTFILES_DIR/$src"
  local dest_abs="$HOME/$rel"

  if [[ ! -e "$src_abs" ]]; then
    echo "skip: $src (missing in repo)"
    return
  fi

  if [[ -L "$dest_abs" ]] && [[ "$(readlink "$dest_abs")" == "$src_abs" ]]; then
    echo "ok:   $rel (already linked)"
    return
  fi

  if [[ -e "$dest_abs" || -L "$dest_abs" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$dest_abs" "$BACKUP_DIR/$rel"
    echo "back: $rel -> $BACKUP_DIR/$rel"
  fi

  mkdir -p "$(dirname "$dest_abs")"
  ln -s "$src_abs" "$dest_abs"
  echo "link: $rel"
}

# Link the per-machine i3 monitor variant:
# ~/.config/i3/local -> $DOTFILES_DIR/.config/i3/monitors-<variant>.
# Idempotent like link_one: backs up a pre-existing real file first.
link_local_variant() {
  local variant="$1"
  local src_abs="$DOTFILES_DIR/.config/i3/monitors-$variant"
  local dest_abs="$HOME/.config/i3/local"

  if [[ ! -e "$src_abs" ]]; then
    echo "skip: .config/i3/monitors-$variant (missing in repo)"
    return
  fi

  if [[ -L "$dest_abs" ]] && [[ "$(readlink "$dest_abs")" == "$src_abs" ]]; then
    echo "ok:   .config/i3/local (already -> monitors-$variant)"
    return
  fi

  if [[ -e "$dest_abs" || -L "$dest_abs" ]]; then
    mkdir -p "$BACKUP_DIR/.config/i3"
    mv "$dest_abs" "$BACKUP_DIR/.config/i3/local"
    echo "back: .config/i3/local -> $BACKUP_DIR/.config/i3/local"
  fi

  mkdir -p "$(dirname "$dest_abs")"
  ln -s "$src_abs" "$dest_abs"
  echo "link: .config/i3/local -> monitors-$variant"
}

# Verify critical symlinks point to dotfiles repo
verify_links() {
  local verify_rels=(
    ".bashrc" ".xprofile" ".Xresources" ".fehbg"
    "Pictures/bg.jpg" "Pictures/bg-old.jpg" "Pictures/new.jpg"
    ".config/i3/config" ".config/i3/scripts"
    ".config/alacritty" ".config/dunst" ".config/flameshot/flameshot.ini"
    ".config/fontconfig" ".config/gtk-3.0/settings.ini" ".config/gtk-4.0/settings.ini"
    ".config/opencode/themes" ".config/opencode/tui.json"
    ".config/picom" ".config/polybar" ".config/rofi" ".config/ttt" ".config/nvim"
    ".config/VSCodium" ".vscode-oss/argv.json" ".config/xsettingsd"
    ".config/disable-mouse-accel.sh"
    ".local/share/themes/Everforest-Green-Dark-Dim"
  )

  local fail=0
  for rel in "${verify_rels[@]}"; do
    local dest="$HOME/$rel"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$DOTFILES_DIR/"* ]]; then
      echo "ok:   $rel -> $(readlink "$dest")"
    else
      echo "MISS: $rel (not linked to \$DOTFILES_DIR)" >&2
      fail=1
    fi
  done

  if [[ $fail -ne 0 ]]; then
    echo "warning: some configs are not linked - re-run $DOTFILES_DIR/install.sh" >&2
  fi
}

# Check for stale literal /home/<user>/ paths in deployed configs
check_stale_paths() {
  local dirs=(
    "$HOME/.config/i3"
    "$HOME/.config/polybar"
    "$HOME/.config/alacritty"
    "$HOME/.fehbg"
  )
  local found=0
  for dir in "${dirs[@]}"; do
    while IFS= read -r -d '' file; do
      if grep -qE "/home/[A-Za-z0-9._-]+/" "$file"; then
        echo "STALE PATH in $file:" >&2
        grep -nE "/home/[A-Za-z0-9._-]+/" "$file" >&2
        found=1
      fi
    done < <(find "$dir" -type f \( -name "*.conf" -o -name "config" -o -name ".fehbg" -o -name "*.sh" -o -name "*.ini" \) -print0 2>/dev/null)
  done
  return $found
}

main() {
  local variant=""
  local do_verify=true
  for arg in "$@"; do
    case "$arg" in
      --desktop) variant="desktop" ;;
      --laptop) variant="laptop" ;;
      --no-verify) do_verify=false ;;
      -h|--help)
        echo "Usage: install.sh [--desktop|--laptop] [--no-verify]"
        return 0
        ;;
      *)
        echo "warn: unknown arg '$arg' (ignored)"
        ;;
    esac
  done

  # hostname heuristic: 'fedora' is the desktop (DP-0 + HDMI-0),
  # anything else is assumed to be the laptop (eDP-1).
  if [[ -z "$variant" ]]; then
    if [[ "$(hostname)" == fedora* ]]; then
      variant="desktop"
    else
      variant="laptop"
    fi
    echo "auto: monitor variant '$variant' (hostname: $(hostname))"
  fi

  echo "Restoring dotfiles from $DOTFILES_DIR"
  for mapping in "${MAPPINGS[@]}"; do
    link_one "$mapping"
  done
  link_local_variant "$variant"

  # Verify critical symlinks point to dotfiles repo
  if [[ "$do_verify" == true ]]; then
    verify_links
    check_stale_paths
  fi

  echo
  echo "Done. Log out/in (or '\$mod+Shift+r' in i3) to apply."
}

main "$@"
#!/usr/bin/env bash
#
# install.sh - restore rod's Everforest i3wm dotfiles
#
# Symlinks config files from this repo into $HOME. It does NOT install
# any packages - run setup.sh for the provisioning steps.
#
# Usage:  ~/dotfiles/install.sh
# Idempotent: safe to re-run. Existing files are backed up first.

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
  ".config/nvim"
  ".config/VSCodium"
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

main() {
  echo "Restoring dotfiles from $DOTFILES_DIR"
  for mapping in "${MAPPINGS[@]}"; do
    link_one "$mapping"
  done

  echo
  echo "Done. Log out/in (or '\$mod+Shift+r' in i3) to apply."
}

main "$@"

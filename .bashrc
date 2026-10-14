#
# ~/.bashrc
#

# --- AWWWARDS_REPO (managed) --- global for all shells/opencode, survives reboots
export AWWWARDS_REPO="https://github.com/Rodsantos1337/min-base.git"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
# Add user-local binaries (yay, etc.)
if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH" in
        *":$HOME/.local/bin:"*) ;;
        *) PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi

# opencode (installed to ~/.opencode/bin by https://opencode.ai/install)
if [ -d "$HOME/.opencode/bin" ]; then
    case ":$PATH" in
        *":$HOME/.opencode/bin:"*) ;;
        *) PATH="$HOME/.opencode/bin:$PATH" ;;
    esac
fi
export TERMINAL=kitty
export EDITOR="ttt"
export VISUAL="ttt"

# zoxide: smart `z <fragment>` jumps (frecency-ranked)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

# fzf: Ctrl+R = history, Ctrl+T = files, Alt+C = cd to dir
# Fedora ships them under shell/, Arch directly under fzf/
for _fzf_base in /usr/share/fzf/shell /usr/share/fzf; do
    [[ -f "$_fzf_base/key-bindings.bash" ]] && source "$_fzf_base/key-bindings.bash"
    [[ -f "$_fzf_base/completion.bash" ]] && source "$_fzf_base/completion.bash"
done
unset _fzf_base

# power-savers: tailscale + syncthing manual toggles (off by default)
tails-on() { sudo systemctl start tailscaled.service && tailscale up; }
tails-off() { tailscale down 2>/dev/null; sudo systemctl stop tailscaled.service; }
sync-on() { systemctl --user start syncthing.service; }
sync-off() { systemctl --user stop syncthing.service; }
share-on() { tails-on && sync-on; }
share-off() { tails-off; sync-off; }
alias quillcode="$HOME/base/quillcode/quillcode-test.sh"
alias test-quillcode="$HOME/base/quillcode/test.sh"


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

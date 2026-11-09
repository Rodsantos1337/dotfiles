#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History (match .zshrc behavior)
HISTFILE="$HOME/.bash_history"
HISTSIZE=100000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
PROMPT_COMMAND='history -a'

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -la'
alias la='ls -A'
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
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


# npm global prefix (~/.npm-global) - matches .zshrc
if [ -d "$HOME/.npm-global/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.npm-global/bin:"*) ;;
        *) PATH="$HOME/.npm-global/bin:$PATH" ;;
    esac
fi

# bun
if [ -d "$HOME/.bun/bin" ]; then
    export BUN_INSTALL="$HOME/.bun"
    case ":$PATH:" in
        *":$HOME/.bun/bin:"*) ;;
        *) PATH="$BUN_INSTALL/bin:$PATH" ;;
    esac
fi










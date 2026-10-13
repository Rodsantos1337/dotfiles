# ~/.zshrc

# --- AWWWARDS_REPO (managed) ---
export AWWWARDS_REPO="https://github.com/Rodsantos1337/min-base.git"

# Enable completion system
autoload -Uz compinit
compinit -d "$HOME/.cache/zcompdump"

# Load completions from system and user
fpath=(
    /usr/share/zsh/site-functions
    /usr/share/zsh/functions/Completion
    "$fpath[@]"
)

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# General options
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt CORRECT
setopt INTERACTIVE_COMMENTS

# Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -la'
alias la='ls -A'

# quillcode aliases
alias quillcode="/home/rod-desktop/base/quillcode/quillcode-test.sh"
alias test-quillcode="/home/rod-desktop/base/quillcode/test.sh"

# power-savers: tailscale + syncthing manual toggles (off by default)
tails-on() { sudo systemctl start tailscaled.service && tailscale up; }
tails-off() { tailscale down 2>/dev/null; sudo systemctl stop tailscaled.service; }
sync-on() { systemctl --user start syncthing.service; }
sync-off() { systemctl --user stop syncthing.service; }
share-on() { tails-on && sync-on; }
share-off() { tails-off; sync-off; }

# Environment
export TERMINAL=alacritty
export EDITOR="codium --wait"
export VISUAL="codium --wait"

# Add user-local binaries
if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH" in
        *":$HOME/.local/bin:"*) ;;
        *) PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi

# opencode
if [ -d "$HOME/.opencode/bin" ]; then
    case ":$PATH" in
        *":$HOME/.opencode/bin:"*) ;;
        *) PATH="$HOME/.opencode/bin:$PATH" ;;
    esac
fi

# zoxide: smart `z <fragment>` jumps (frecency-ranked)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# fzf: Ctrl+R = history, Ctrl+T = files, Alt+C = cd to dir
for _fzf_base in /usr/share/fzf/shell /usr/share/fzf; do
    [[ -f "$_fzf_base/key-bindings.zsh" ]] && source "$_fzf_base/key-bindings.zsh"
    [[ -f "$_fzf_base/completion.zsh" ]] && source "$_fzf_base/completion.zsh"
done
unset _fzf_base

# zsh plugins (installed via dnf)
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null

# Prompt (simple, like bash PS1)
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f%# '

# Added by Antigravity CLI installer
export PATH="/home/rod-desktop/.local/bin:$PATH"

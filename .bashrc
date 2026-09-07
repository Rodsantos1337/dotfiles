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
export TERMINAL=alacritty
export EDITOR="codium --wait"
export VISUAL="codium --wait"

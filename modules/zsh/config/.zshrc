# Fig pre
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"


# Aliases
[[ -f "$HOME/.config/zsh/aliases/base-aliases.zsh" ]] && source ~/.config/zsh/aliases/base-aliases.zsh
[[ -f "$HOME/.config/zsh/aliases/docker-aliases.zsh" ]] && source ~/.config/zsh/aliases/docker-aliases.zsh
[[ -f "$HOME/.config/zsh/aliases/git-aliases.zsh" ]] && source ~/.config/zsh/aliases/git-aliases.zsh
[[ -f "$HOME/.config/zsh/aliases/languages-aliases.zsh" ]] && source ~/.config/zsh/aliases/languages-aliases.zsh
[[ -f "$HOME/.config/zsh/aliases/network-aliases.zsh" ]] && source ~/.config/zsh/aliases/network-aliases.zsh
[[ -f "$HOME/.config/zsh/aliases/shortcuts-aliases.zsh" ]] && source ~/.config/zsh/aliases/shortcuts-aliases.zsh

# Other imports
[[ -f "$HOME/.config/zsh/functions.zsh" ]] && source ~/.config/zsh/functions.zsh
[[ -f "$HOME/.config/zsh/wsl2fix.zsh" ]] && source ~/.config/zsh/wsl2fix.zsh
[[ -f "$HOME/.config/zsh/goto.zsh" ]] && source ~/.config/zsh/goto.zsh

# Load LFCD
LFCD="$GOPATH/src/github.com/gokcehan/lf/etc/lfcd.sh"  # source
LFCD="/Users/yoshintame/.config/lf/scripts/lfcd.sh"  #  pre-built binary, make sure to use absolute path
if [ -f "$LFCD" ]; then
    source "$LFCD"
fi
bindkey -s '^o' 'lfcd^M' # TODO not working

# Load Starship
eval "$(starship init zsh)"

# Load Rtx
# eval "$(~/bin/rtx activate zsh)"

# # Load Direnv
# eval "$(direnv hook zsh)"

export PATH="$HOME/bin:$PATH"

# Fig post
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"

# Pnpm
export PNPM_HOME="/Users/yoshintame/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

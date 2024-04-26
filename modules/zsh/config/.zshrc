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
[[ -f "$HOME/.config/yazi/scripts/yy.sh" ]] && source ~/.config/yazi/scripts/yy.sh

# Load Starship
eval "$(starship init zsh)"

# Load Zoxide
eval "$(zoxide init zsh)"

# Pnpm
export PNPM_HOME="/Users/yoshintame/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Code plugins
PATH=~/.console-ninja/.bin:$PATH

printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh" }}\x9c'

# bun completions
[ -s "/Users/yoshintame/.bun/_bun" ] && source "/Users/yoshintame/.bun/_bun"

# Binds
bindkey -s '^o' 'fj^M' # TODO not workingj


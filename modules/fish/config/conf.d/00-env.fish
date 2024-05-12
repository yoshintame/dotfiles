# Ensure critical universals exist
set -qU XDG_CONFIG_HOME; or set -Ux XDG_CONFIG_HOME $HOME/.config
set -qU XDG_DATA_HOME; or set -Ux XDG_DATA_HOME $HOME/.local/share
set -qU XDG_CACHE_HOME; or set -Ux XDG_CACHE_HOME $HOME/.cache

# Main
set -gx EDITOR cursor
set -gx VISUAL cursor
set -gx PLAY iina

# FZF
set -gx FZF_COMPLETION_OPTS '--color=16 --layout=reverse --inline-info'
set -gx FZF_DEFAULT_OPTS '--color=16 --layout=reverse --inline-info'

set -gx PATH bin $PATH
set -gx PATH ~/bin $PATH
set -gx PATH ~/.local/bin $PATH

# NodeJS
set -gx PATH node_modules/.bin $PATH

# Go
set -g GOPATH $HOME/go
set -gx PATH $GOPATH/bin $PATH

# Path
set -g TRASH $HOME/.Trash
set -g DOTFILES $HOME/.dotfiles

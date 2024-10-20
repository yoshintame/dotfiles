# Ensure critical universals exist
set -qU XDG_CONFIG_HOME; or set -Ux XDG_CONFIG_HOME $HOME/.config
set -qU XDG_DATA_HOME; or set -Ux XDG_DATA_HOME $HOME/.local/share
set -q XDG_STATE_HOME; or set -Ux XDG_STATE_HOME $HOME/.local/state
set -qU XDG_CACHE_HOME; or set -Ux XDG_CACHE_HOME $HOME/.cache
set -q __fish_cache_dir; or set -Ux __fish_cache_dir $XDG_CACHE_HOME/fish

# Main
set -gx EDITOR cursor
set -gx VISUAL cursor
set -gx PLAY iina

# Zoxide
set -u zoxide_cmd j

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
set -gx TRASH $HOME/.Trash

# Fisher
set -Ux fisher_path /Users/yoshintame/.config/fish/fisher_plugins

# 1password
set -e SSH_AUTH_SOCK
set -Ux SSH_AUTH_SOCK ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

# Dofiles
set -gx DOTFILES $HOME/.dotfiles
set -gx DOTFILES_CONFIG $DOTFILES/os/macos/module.yaml

# GRC
set -gx grc_plugin_ignore_execs ls

# Fish
set -gx aliases_path $__fish_config_dir/aliases
set fish_function_path $fish_function_path[1] $aliases_path $fish_function_path[2..]

# SmartEmptyLine
set -gx SMART_RIGHT_CMD "yy"
set -gx SMART_RIGHT_GIT_CMD "yy"
set -gx SMART_RIGHT_OPT_CMD "ji"
set -gx SMART_RIGHT_OPT_GIT_CMD "ji"
set -gx SMART_LEFT_CMD ".."
set -gx SMART_LEFT_GIT_CMD ".."
set -gx SMART_ENTER_CMD "ls"
set -gx SMART_ENTER_GIT_CMD "git status -sb"

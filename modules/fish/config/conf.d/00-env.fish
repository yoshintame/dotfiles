set -q __fish_cache_dir; or set -Ux __fish_cache_dir $XDG_CACHE_HOME/fish

set -gx PATH node_modules/.bin $PATH

set -gx grc_plugin_ignore_execs ls

set -gx aliases_path $__fish_config_dir/aliases
set fish_function_path $fish_function_path[1] $aliases_path $fish_function_path[2..]

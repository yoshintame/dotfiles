set -q __fish_cache_dir; or set -Ux __fish_cache_dir $XDG_CACHE_HOME/fish

set -gx PATH node_modules/.bin $PATH

set -gx grc_plugin_ignore_execs ls

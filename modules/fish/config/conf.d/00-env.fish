set -q __fish_cache_dir; or set -Ux __fish_cache_dir $XDG_CACHE_HOME/fish

set -gx PATH node_modules/.bin $PATH

set -gx grc_plugin_ignore_execs ls

function __vtb_tz --on-variable PWD
    if string match -q -- "$HOME/Development/work/vtb/*" $PWD
        set -gx TZ Europe/Moscow
    else if set -q TZ
        set -e TZ
    end
end
__vtb_tz

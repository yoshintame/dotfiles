set -q __fish_cache_dir; or set -Ux __fish_cache_dir $XDG_CACHE_HOME/fish

set -gx PATH node_modules/.bin $PATH

set -gx grc_plugin_ignore_execs ls

function __vtb_tz --on-variable PWD
    set -l tz
    if string match -q -- "$HOME/Development/work/vtb/*" $PWD
        set tz Europe/Moscow
    else
        set tz (command git config --get vtb.tz 2>/dev/null)
    end
    if test -n "$tz"
        set -gx TZ $tz
    else if set -q TZ
        set -e TZ
    end
end
__vtb_tz


function _fish_selection_move
    set -l direction $argv[1]
    if test -z (commandline --selection-start)
        commandline -f begin-selection
    end
    commandline -f $direction
end

function _fish_smart_backspace
    if commandline --selection-start >/dev/null 2>&1
        commandline -f kill-selection end-selection
    else
        commandline -f backward-delete-char
    end
end

function _fish_smart_delete
    if commandline --selection-start >/dev/null 2>&1
        commandline -f kill-selection end-selection
    else
        commandline -f delete-char
    end
end

function _fish_is_git_repo
    command git rev-parse --is-inside-work-tree &>/dev/null
    return $status
end

function _fish_get_smart_cmd
    set -l default_cmd $argv[1]
    set -l git_cmd $argv[2]
    if _fish_is_git_repo
        echo $git_cmd
    else
        echo $default_cmd
    end
end

function _fish_smart_enter
    set -l default_cmd $argv[1]
    set -l git_cmd $argv[2]
    if test -z (commandline | string collect)
        set -l cmd (_fish_get_smart_cmd $default_cmd $git_cmd)
        if test -n "$cmd"
            commandline -r -- "$cmd"
            commandline -f suppress-autosuggestion
        end
    end
    commandline -f execute
end

function _fish_smart_arrow
    set -l direction $argv[1]
    set -l default_cmd $argv[2]
    set -l git_cmd $argv[3]
    if test -z (commandline | string collect)
        set -l cmd (_fish_get_smart_cmd $default_cmd $git_cmd)
        if test -n "$cmd"
            commandline -r -- "$cmd"
            commandline -f execute
        end
    else
        if commandline --selection-start >/dev/null 2>&1
            commandline -f end-selection
        end
        commandline -f $direction
    end
end

bind \e\[3\;3~ kill-word
bind \e\[1\;3L forward-word
bind \ez undo
bind super-delete kill-line

bind shift-left '_fish_selection_move backward-char'
bind shift-right '_fish_selection_move forward-char'
bind alt-shift-left '_fish_selection_move backward-word'
bind alt-shift-right '_fish_selection_move forward-word'

bind backspace _fish_smart_backspace
bind delete _fish_smart_delete

set -l smart_left_cmd ".."
set -l smart_left_git_cmd ".."
set -l smart_right_cmd "yy"
set -l smart_right_git_cmd "yy"
set -l smart_enter_cmd "ls"
set -l smart_enter_git_cmd "git status -sb"

bind \r "_fish_smart_enter '$smart_enter_cmd' '$smart_enter_git_cmd'"
bind \e\[D "_fish_smart_arrow backward-char $smart_left_cmd $smart_left_git_cmd"
bind \e\[C "_fish_smart_arrow forward-char $smart_right_cmd $smart_right_git_cmd"

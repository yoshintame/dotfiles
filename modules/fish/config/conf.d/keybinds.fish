bind \e\[3\;3~ kill-word
bind \e\[1\;3L forward-word
bind \ez undo
bind super-delete kill-line

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

bind shift-left '_fish_selection_move backward-char'
bind shift-right '_fish_selection_move forward-char'
bind alt-shift-left '_fish_selection_move backward-word'
bind alt-shift-right '_fish_selection_move forward-word'

bind backspace _fish_smart_backspace
bind delete _fish_smart_delete

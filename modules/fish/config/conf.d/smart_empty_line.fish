function is_git_repo
    command git rev-parse --is-inside-work-tree &>/dev/null
    return $status
end

function get_cmd
    set -l default_cmd $argv[1]
    set -l git_cmd $argv[2]
    if is_git_repo
        echo $git_cmd
    else
        echo $default_cmd
    end
end

function on_enter
    # NOTE: `commandline` may output multiple lines for multi-line input.
    # Command substitutions split on newlines, so we collect it back into a single string.
    if test -z (commandline | string collect)
        set -l cmd (get_cmd $SMART_ENTER_CMD $SMART_ENTER_GIT_CMD)
        if test -n "$cmd"
            commandline -r -- "$cmd"
            commandline -f suppress-autosuggestion
        end
    end
    commandline -f execute
end

function on_arrow
    set -l direction $argv[1]
    set -l default_cmd $argv[2]
    set -l git_cmd $argv[3]
    if test -z (commandline | string collect)
        set -l cmd (get_cmd $default_cmd $git_cmd)
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

bind \e\[D "on_arrow backward-char $SMART_LEFT_CMD $SMART_LEFT_GIT_CMD"
bind \e\[C "on_arrow forward-char $SMART_RIGHT_CMD $SMART_RIGHT_GIT_CMD"



